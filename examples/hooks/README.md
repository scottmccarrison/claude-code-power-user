# Example Hooks

Production hook scripts extracted from a real Claude Code setup. Copy what's useful, modify for your environment.

## Files

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `block-main-commit.sh` | PreToolUse | `Bash` | Block git commits directly to main/master |
| `lint-python.sh` | PostToolUse | `Edit\|Write` | Auto-lint Python files after edits |
| `session-context.sh` | SessionStart | `""` | Inject machine identity, git state, open PRs |

## Installation

1. Copy scripts to `~/.claude/hooks/`
2. Make executable: `chmod +x ~/.claude/hooks/*.sh`
3. Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/session-context.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "~/.claude/hooks/block-main-commit.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "~/.claude/hooks/lint-python.sh"}]}
    ]
  }
}
```

## Writing Your Own

- All hooks receive JSON on stdin with context (cwd, tool_input, session_id, etc.)
- Exit 0 = success/allow
- Exit 2 = block (PreToolUse, Stop, and other blocking events)
- Parse JSON with `python3 -c "..."` one-liners for cross-platform compatibility
- Test manually: `echo '{"tool_input":{"command":"git commit"}}' | ./block-main-commit.sh`
