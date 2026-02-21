# Hooks — Deterministic Automation

## Why Hooks > Instructions

CLAUDE.md is advisory. The model reads it, weighs it against everything else, and sometimes ignores it. Hooks are code. They run unconditionally.

The distinction matters when the stakes are real:

- "Never commit to main" in CLAUDE.md → violated occasionally, especially mid-task when Claude is focused on something else
- PreToolUse hook that calls `exit 2` on main/master → never violated, ever

If something must happen with zero exceptions, it belongs in a hook, not a markdown file. Use CLAUDE.md for preferences and working style. Use hooks for invariants.

---

## Available Hook Events

| Event | When It Fires | Can Block | Typical Use |
|---|---|---|---|
| `SessionStart` | Once at session open | No | Inject machine identity, git state, memories |
| `UserPromptSubmit` | Before each user message is processed | Yes | Intercept vague prompts, enforce formatting |
| `PreToolUse` | Before any tool call | Yes | Block dangerous commands, enforce branch rules |
| `PermissionRequest` | When Claude requests permission for an action | Yes | Auto-approve safe patterns, block risky ones |
| `PostToolUse` | After a tool succeeds | No | Lint edited files, log operations |
| `PostToolUseFailure` | After a tool fails | No | Alert on repeated failures, log errors |
| `Notification` | When Claude sends a notification | No | Route alerts to Slack, push, etc. |
| `SubagentStart` | When a subagent is spawned | No | Log agent metrics, inject subagent context |
| `SubagentStop` | When a subagent completes | No | Collect agent output, aggregate results |
| `Stop` | After each assistant response | No | Save turn to persistent memory |
| `TaskCompleted` | When a task finishes | No | Post-task reporting, cleanup |
| `PreCompact` | Before context compaction | No | Force preservation of specific content |
| `SessionEnd` | When session closes | No | Archive transcript, build session summary |

"Can Block" means the hook can return exit code 2 to prevent the action. Exit code 0 = success. Anything else = error (logged, but not blocking unless it's a PreToolUse).

---

## Three Hook Types

**Command** — A shell script or binary. Receives JSON on stdin, writes to stdout/stderr, exits with a code. The workhorse type. Use for 95% of hooks.

**Prompt** — A single-turn LLM call that evaluates the hook context. The model's response determines what happens. Use when you want fuzzy matching ("is this command dangerous?") instead of exact pattern matching.

**Agent** — A full multi-turn subagent with tools. Overkill for most hooks, but powerful when you need to take real actions in response to events (e.g., auto-opening a GitHub issue when a deploy fails).

---

## The Five Essential Hooks

### 1. SessionStart: Context Injection

Claude starts every session blind. It doesn't know which machine you're on, what branch you're working in, or what you were doing yesterday. This hook surfaces that automatically.

```bash
#!/bin/bash
# ~/.claude/hooks/session-context.sh
# SessionStart hook: inject machine identity and project context

INPUT=$(cat)
CWD=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('cwd',''))" <<< "$INPUT" 2>/dev/null)

# Machine identity
MACHINE=$(cat ~/.claude-machine 2>/dev/null || hostname)
echo "Machine: $MACHINE"

# Git state
if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    PROJECT=$(basename "$CWD")
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    RECENT=$(git -C "$CWD" log --oneline -3 2>/dev/null)

    echo "Project: $PROJECT | Branch: $BRANCH"
    [ "$DIRTY" -gt 0 ] && echo "Uncommitted: $DIRTY files"
    echo "Recent commits:"
    echo "$RECENT" | sed 's/^/  /'

    # Open PRs (requires gh CLI)
    if command -v gh &>/dev/null; then
        PRS=$(gh pr list --state open --limit 3 --json number,title 2>/dev/null | \
              python3 -c "import json,sys; prs=json.load(sys.stdin); [print(f'  #{p[\"number\"]}: {p[\"title\"]}') for p in prs]" 2>/dev/null)
        [ -n "$PRS" ] && echo "Open PRs:" && echo "$PRS"
    fi
fi

exit 0
```

What this gives Claude at session open: which machine it's on, which branch is active, whether there's unsaved work, what was recently committed, and what PRs are in flight. No more "let me check git status" as the first act of every session.

---

### 2. PreToolUse (Bash matcher): Branch Protection

The canonical example of why hooks beat instructions. This runs before every Bash tool call and exits 2 (blocking) if Claude tries to commit directly to main.

```bash
#!/bin/bash
# ~/.claude/hooks/block-main-commit.sh
# PreToolUse hook: block git commits to main/master

INPUT=$(cat)
COMMAND=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" <<< "$INPUT" 2>/dev/null)

# Only care about commit commands
if echo "$COMMAND" | grep -qE 'git\s+commit'; then
    # Extract working directory from the command context if possible
    # Fall back to cwd from hook input
    HOOK_CWD=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('cwd', ''))
" <<< "$INPUT" 2>/dev/null)

    BRANCH=$(git -C "${HOOK_CWD:-.}" branch --show-current 2>/dev/null)

    # Exempt the docs repo — direct commits to main are intentional there
    REPO=$(basename "$(git -C "${HOOK_CWD:-.}" rev-parse --show-toplevel 2>/dev/null)")

    if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] && [[ "$REPO" != "docs" ]]; then
        echo "Blocked: committing directly to '$BRANCH' in '$REPO'. Create a feature branch first." >&2
        exit 2
    fi
fi

exit 0
```

The exemption pattern (`[[ "$REPO" != "docs" ]]`) is important. Some repos legitimately take direct commits to main. Hard-coding blanket rules breaks those workflows. Build exemptions in from day one.

---

### 3. PostToolUse (Edit|Write matcher): Auto-Lint

Catches syntax errors the moment a file is written, before Claude moves on to the next step. Without this, Claude writes a broken file, runs it three steps later, hits an error, has to debug backwards to find the typo.

```bash
#!/bin/bash
# ~/.claude/hooks/lint-python.sh
# PostToolUse hook: lint Python files immediately after Edit/Write

INPUT=$(cat)
FILE_PATH=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" <<< "$INPUT" 2>/dev/null)

if [[ "$FILE_PATH" == *.py ]] && [[ -f "$FILE_PATH" ]]; then
    OUTPUT=$(python3 -m py_compile "$FILE_PATH" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Syntax error in $FILE_PATH:" >&2
        echo "$OUTPUT" >&2
    fi
fi

# Extend for other languages:
# [[ "$FILE_PATH" == *.ts ]] && npx tsc --noEmit "$FILE_PATH" 2>&1
# [[ "$FILE_PATH" == *.sh ]] && bash -n "$FILE_PATH" 2>&1

exit 0
```

PostToolUse hooks can't block (they run after the action), but they output to stderr which Claude sees immediately and acts on. The feedback loop is: write file → hook runs → Claude sees error → Claude fixes it, all within the same response cycle.

---

### 4. Stop: Per-Turn Memory Save

Every assistant response is a potential loss event if the session crashes. This hook fires after each Stop event (end of each assistant response) and saves the turn to a persistent memory store.

The hook architecture:

1. Read transcript JSONL from `transcript_path` in the hook input
2. Extract the last user message and last assistant response
3. Classify the action type: `debug`, `deploy`, `implement`, `configure`, `refactor`, `review`, `research`
4. Extract topics via regex: tool names, infra references, repo names, file paths
5. POST to a memory API (in this setup: Brain API backed by PostgreSQL + pgvector)
6. Silent fail — if the API is down, the hook exits 0 and Claude never knows

The silent fail on step 6 is non-negotiable. A memory hook that crashes and blocks Claude is worse than no memory hook. Wrap the API call in a try/except, log failures to a local file, exit 0 regardless.

```python
#!/usr/bin/env python3
# ~/.claude/hooks/save-to-brain-mem.py
# Stop/SessionEnd hook: persist turn to memory API

import json, sys, os, re, requests
from datetime import datetime

def classify_action(text):
    text = text.lower()
    if any(w in text for w in ['fix', 'bug', 'error', 'traceback', 'exception']): return 'debug'
    if any(w in text for w in ['deploy', 'restart', 'systemctl', 'push']): return 'deploy'
    if any(w in text for w in ['implement', 'create', 'add feature', 'build']): return 'implement'
    if any(w in text for w in ['refactor', 'rename', 'restructure']): return 'refactor'
    if any(w in text for w in ['review', 'pr', 'pull request']): return 'review'
    return 'general'

try:
    data = json.load(sys.stdin)
    transcript_path = data.get('transcript_path', '')

    if not transcript_path or not os.path.exists(transcript_path):
        sys.exit(0)

    turns = []
    with open(transcript_path) as f:
        for line in f:
            try:
                turns.append(json.loads(line.strip()))
            except Exception:
                pass

    if not turns:
        sys.exit(0)

    # Extract last user + assistant pair
    user_msg = next((t['content'] for t in reversed(turns) if t.get('role') == 'user'), '')
    asst_msg = next((t['content'] for t in reversed(turns) if t.get('role') == 'assistant'), '')

    if isinstance(asst_msg, list):
        asst_msg = ' '.join(b.get('text', '') for b in asst_msg if isinstance(b, dict))

    combined = f"{user_msg}\n{asst_msg}"
    action_type = classify_action(combined)

    # Extract topics
    topics = re.findall(r'[\w-]+\.py|[\w-]+\.swift|[\w-]+\.ts', combined)
    topics += re.findall(r'my-backend|my-ios-app|my-web-app', combined, re.I)

    payload = {
        'title': f"{action_type}: {user_msg[:80]}",
        'content': combined[:4000],
        'tags': list(set(topics))[:10],
        'metadata': {'action_type': action_type, 'saved_at': datetime.utcnow().isoformat()}
    }

    requests.post(
        'http://your-memory-api.example.com/api/memory',
        json=payload,
        timeout=5,
        headers={'Authorization': f"Bearer {os.environ.get('BRAIN_API_KEY', '')}"}
    )

except Exception:
    pass  # Never block Claude on memory failure

sys.exit(0)
```

---

### 5. SessionEnd: Transcript Archive + Session Summary

The Stop hook saves individual turns. SessionEnd saves the whole session as a structured unit.

What it does:

1. Archives raw JSONL transcript to `~/.claude/archives/YYYY-MM-DD/session-{id}.jsonl`
2. Builds a session summary: duration, turn count, repos touched, actions taken, files modified
3. Saves summary to memory API with session-level tags
4. Caps output at ~4000 chars to stay within embedding limits

The archive step is critical. Claude Code's transcript files are ephemeral — they disappear when the session is cleaned up. If you want to audit what happened in a session two weeks ago, or train on your own usage patterns, you need to archive before the files are gone.

---

## Configuration in settings.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-context.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-main-commit.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/lint-python.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/save-to-brain-mem.py"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/archive-session.sh"
          }
        ]
      }
    ]
  }
}
```

The `matcher` field is a regex matched against the tool name. Empty string matches everything. `"Edit|Write"` matches either. `"Bash"` matches only the Bash tool.

---

## Hook Development Tips

**JSON parsing**: Use python3 one-liners rather than `jq`. Python is always available; jq isn't.

```bash
FIELD=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" <<< "$INPUT")
```

**Testing manually**: Hooks are just scripts. Test them before wiring them up.

```bash
echo '{"tool_input":{"command":"git commit -m test"}, "cwd":"/home/scott/myrepo"}' \
  | ~/.claude/hooks/block-main-commit.sh
echo "Exit: $?"
```

**Exit codes**: Exit 0 for success. Exit 2 to block (PreToolUse only). Any other non-zero exits are logged as errors but don't block. Never rely on non-zero exit to block anything other than tool calls.

**Stderr surfaces to Claude**: Anything written to stderr appears in Claude's context. This is how blocking hooks communicate why they blocked. Be specific — "Blocked: committing to main in brain. Use a feature branch." is actionable. "Error" is not.

**Always exit 0 at the end** unless you intend to block. A hook that exits non-zero unexpectedly causes noise and can interfere with the session.

**Silent fail for non-critical hooks**: Memory saves, analytics, notifications — wrap everything in try/except and exit 0. The session must never depend on a hook succeeding.

**Keep hooks fast**: Hooks run synchronously in the session flow. A SessionStart hook that takes 10 seconds to query a slow API delays every session start. Set short timeouts on any network calls. If something is slow, background it with `&` and don't wait for it.

---

## What I Haven't Hooked Yet (And What I Tried)

These events exist but aren't wired up in this setup. Some were tested and deliberately removed.

### UserPromptSubmit - Tested, Removed

I built a prompt-type hook that evaluated whether each user message was specific enough to act on. The prompt had an auto-approve list (short confirmations, slash commands, follow-ups, pasted code), a strict rejection criteria (only reject when the prompt was vague on multiple dimensions), and an explicit "when in doubt, APPROVE" bias.

**What happened:** The hook blocked most legitimate prompts, including prompts trying to fix the hook itself. A catch-22 - the quality gate rejected the very messages needed to adjust its sensitivity. Even with careful prompt engineering and a permissive bias, the LLM evaluation was too unpredictable for a gate that fires on every single interaction.

**The core problems:**

- **Prompt-type hooks add 700ms-2s per interaction.** Every message - including "yes", "looks good", "continue" - pays the latency tax of a Haiku LLM call. That's noticeable.
- **No prompt rewriting.** You can block or augment context, but you can't fix a vague prompt. The user has to retype from scratch.
- **Claude doesn't see the rejection reason.** Exit code 2 erases the prompt entirely. Stderr goes to the user but not to Claude. So Claude can't help improve the prompt.
- **No matcher filtering.** The hook fires on everything with no way to skip trivial prompts. Your filtering logic has to live inside the script.
- **The real problem is fuzzy.** Regex catches obviously bad prompts ("fix it", "make it work"), but the prompts that actually waste Opus turns are subtly vague, not obviously vague. That's where you need LLM judgment, and that's where the latency tax hits.

**Verdict:** If you want a prompt quality gate, use a command hook with simple regex patterns - fast, deterministic, easy to debug. Skip the LLM evaluation. The prompts that regex catches aren't the ones costing you money, and the ones costing you money need LLM judgment that adds unacceptable latency.

### SubagentStart / SubagentStop - Deferred

Could log agent spawn/completion metrics, inject subagent-specific context, or build an audit trail. The data available today is incomplete:

- **SubagentStop** doesn't include token usage, cost, or duration. You'd have to parse the agent's transcript file to derive these.
- **Neither hook** tells you if the agent is running Haiku, Sonnet, or Opus. You'd have to parse transcript content or infer from agent type.
- **SubagentStart can't block.** Exit code 2 only shows stderr to the user. The agent launches anyway.
- **No parent agent ID.** If agents spawn sub-agents, you can't build a hierarchy tree from hook data alone.

What you can get (agent type, last message, transcript path) is useful for audit logging but not for the calibration metrics you actually want. Deferred until Anthropic adds token/cost/model fields to SubagentStop.

### PreCompact - Deferred

PreCompact **cannot inject context** - no `additionalContext` output field, can't block compaction. The correct pattern is a SessionStart hook with `matcher: "compact"` to re-inject context *after* compaction. Two-hook solution, medium effort, not the quick win it appears to be.

### PermissionRequest

Could auto-approve a whitelist of known-safe operations and auto-deny a blacklist of known-dangerous ones. Currently everything goes through Claude's judgment plus the interactive prompt.

The gap between this setup and full coverage of all events is real, but the gaps are now informed by testing rather than speculation. Some hooks aren't worth the tradeoffs today.
