# CLAUDE.md — The Foundation

## What It Does

CLAUDE.md is a markdown file that Claude Code reads at the start of every session. It's persistent, project-scoped instruction that shapes every interaction — without you having to repeat yourself.

**File hierarchy** (highest to lowest priority):

| Level | Location | Scope |
|-------|----------|-------|
| Managed policy | Anthropic-enforced | Always active |
| Project | `CLAUDE.md` at repo root | All sessions in this project |
| Project rules | `.claude/rules/*.md` | Scoped to paths or topics |
| User | `~/.claude/CLAUDE.md` | All your projects |
| Local | `CLAUDE.md.local` (gitignored) | Your machine only |
| Auto memory | `~/.claude/projects/.../memory/` | Injected automatically |

**Key insight**: CLAUDE.md is the highest-ROI investment you can make in Claude Code. A well-written one eliminates an entire category of repeated corrections. A bad one gets ignored or creates noise.

---

## What to Put In It

### Session Start Procedures

Claude can't remember between sessions. Use CLAUDE.md to bootstrap context on every startup — machine detection, repo sync, memory recall.

```markdown
## Session Start - Do This First

0. **Identify machine**: `hostname`
1. **Sync docs repo**: `git -C ~/docs pull --ff-only`
2. **Search brain-mem** for prior context: `brain-mem search "<topic>" --top 5`
3. **Load /context-load** if topic matches: `meal-planning`, `therapy`, `costa-rica`
```

This pattern is especially useful if you work across multiple machines. A marker file (e.g., `~/.claude-machine`) with a known value lets Claude branch behavior: different SSH targets, different deploy commands, different assumptions.

### Working Style Preferences

Tell Claude how you want it to behave before it starts coding:

```markdown
## Working Style

Always enter plan mode before making code changes, unless the task is trivially
simple (typo fix, single-line change). Present the plan, get approval, then execute.

This applies to:
- New features or endpoints
- Refactoring or restructuring
- Multi-file changes
- Anything touching auth, data models, or API contracts
```

Without this, Claude will often just start editing files. With it, you get a review checkpoint before things change.

Also worth specifying:

- **PR workflow**: "Auto-merge PRs immediately after creating them, unless something is risky. Use `Closes #N` in PR body."
- **When to ask vs. proceed**: "If the target machine is unclear, ask. Don't guess."
- **Branch conventions**: "Always use feature branches. Never push directly to main."

### Agent Delegation Rules

If you use sub-agents (via Task tool or `/agents`), tell Claude how to delegate:

```markdown
## Agent Delegation

- Opus: orchestration, planning, complex reasoning
- Sonnet: implementation, multi-file edits
- Haiku: research, file exploration, quick lookups

Context budget: if a task needs 3+ rounds of file exploration before any edits,
delegate to a sub-agent rather than burning context on the primary session.

Always verify agent output before reporting success — read modified files,
check PRs exist and look correct.
```

A concrete rule like "3+ tool calls for research? Delegate" gives Claude something actionable, not vague guidance.

### Compact and Context Instructions

Tell Claude what matters when compacting:

```markdown
## Compact Instructions

Preserve: file paths, code changes, decisions + rationale, task state,
git state (branch/commits/PRs), errors + fixes.

Discard: exploratory reads that didn't lead to changes, verbose tool output
already summarized, intermediate search results.

/compact proactively after completing a major task — don't wait for auto-compaction.
```

This prevents the "I compacted and lost everything that mattered" problem.

### Memory Search Hooks

If you use an external memory system (vector store, brain-mem, etc.), put the search commands in CLAUDE.md so Claude uses them at session start and when encountering relevant topics:

```markdown
## Brain-Mem

Search: `~/.local/bin/brain-mem search "<query>" --top 5`
Save: `~/.local/bin/brain-mem save --title "Description" "content"`

Manual saves are useful for: high-level decisions, architectural summaries,
synthesized insights. Hooks handle raw turn-by-turn saves automatically.
```

---

## What NOT to Put In

**Your entire architecture doc.** Link to it instead:

```markdown
# Bad
## Architecture
The iOS app uses SwiftData for local caching. The cache layer lives in
Models/Cache/ and uses a MutationQueue pattern for offline support.
Each cached model has a corresponding SwiftData entity. The queue is
drained on network reconnect via a NotificationCenter observer...

# Good
Architecture reference: `~/docs/guides/mcdev-guide.md`
```

**Things Claude already knows.** Don't write "use snake_case for Python variables" or "always add error handling." Claude knows Python conventions.

**File-by-file descriptions.** Claude can read the repo. If the structure isn't obvious, fix the structure.

**Overly detailed prose.** Short imperatives beat paragraphs:

```markdown
# Bad
When working on this project, you should be careful to always make sure
that you create a feature branch before making any changes, because we
have branch protection enabled on main and direct pushes will be rejected.

# Good
Always use feature branches. Never push directly to main.
```

---

## Modular Rules (.claude/rules/)

For rules that only apply in certain contexts, use `.claude/rules/` instead of cluttering CLAUDE.md.

**File-scoped rules** with `paths:` frontmatter:

```markdown
---
paths:
  - "**/*.swift"
---

# iOS Swift Rules

- Use `async/await` over completion handlers
- All network calls go through `APIService`
- SwiftData models live in `Models/Cache/`
- Never import UIKit in a SwiftUI file
```

```markdown
---
paths:
  - "backend/**/*.py"
---

# Python Backend Rules

- FastAPI dependency injection for DB sessions
- All endpoints require auth unless decorated with @public
- Pydantic models for all request/response schemas
```

**When to use rules vs. CLAUDE.md:**

| Use CLAUDE.md | Use .claude/rules/ |
|---------------|-------------------|
| Session startup procedures | Language-specific conventions |
| Cross-cutting workflow preferences | Path-scoped constraints |
| Agent delegation policy | Tech-stack-specific patterns |
| Memory/context management | Team conventions for a subdirectory |

---

## The CLAUDE.md Anti-Patterns

**1. Dumping your architecture doc into it.**
CLAUDE.md gets read every session. Long files cause Claude to skim or miss important items. Keep it under 150 lines; link out to docs for everything else.

**2. Writing instructions so long Claude ignores them.**
If your session start procedure is 20 steps, Claude will skip steps. Ruthlessly cut. If a step is critical, make it a hook instead (hooks always run).

**3. Duplicating what linters/formatters already enforce.**
If your CI runs `ruff` and `black`, don't write "follow PEP 8" in CLAUDE.md. The tooling handles it. Save CLAUDE.md for things the tools can't check.

**4. Not updating it when patterns change.**
CLAUDE.md reflects how your project actually works. When you change your deploy process, update CLAUDE.md that day. Stale instructions are worse than no instructions — Claude will follow them confidently into broken territory.

**5. Using it as a substitute for good project structure.**
If Claude constantly gets confused about where files go, the answer might be better directory organization, not more CLAUDE.md text.

---

## Key Insight: Treat It Like Onboarding Notes

Write CLAUDE.md as if you're writing notes for a new engineer starting on the project — someone competent who doesn't need to be told what a for loop is, but does need to know:

- What the deploy command is
- Which patterns are preferred (and which are legacy)
- What not to touch without checking first
- How the team handles PRs and issues

**If you wouldn't tell a new hire this on day 1, don't put it in CLAUDE.md.**

**If Claude keeps making the same mistake, add a rule for it.** Every correction you give twice is a CLAUDE.md entry waiting to be written.

**If the instruction is critical (must never be violated), use a hook instead.** Hooks run unconditionally. CLAUDE.md instructions are advisory — Claude follows them, but a long session with lots of context can cause drift. For hard constraints (never push to main, always run tests before committing), hooks are the right tool.

---

## Real Example: Production CLAUDE.md Structure

This is the structure for a project with an iOS frontend, Python/FastAPI backend, and shared config repo:

```markdown
# CLAUDE.md

## Session Start - Do This First
0. `hostname` — identify machine
1. `git -C ~/docs pull --ff-only` — sync shared config
2. `brain-mem search "<topic>" --top 5` — recall prior context
3. Load /context-load for: meal-planning, mcdev

## Machine Detection
Check `~/.claude-machine`. Machine overrides: `~/docs/machines/<machine>/overrides.md`

## Git Workflow
Feature branches + PRs. Never push to main. Auto-merge unless risky.
Use `Closes #N` in PR body. Full workflow: `~/docs/guides/git-workflow.md`

## Working Style
Plan mode before any multi-file change. Present plan → get approval → execute.
Delegate deep exploration to sub-agents (separate context windows).

## Agent Instructions
- Include exact file paths and before/after snippets in plans
- Group independent work into parallel agents by repo/area
- Verify agent output before reporting success

## Compact Instructions
Preserve: file paths, code changes, decisions, git state, errors + fixes.
Discard: exploratory reads, verbose output already summarized.
/compact proactively after major tasks.

## Reference Docs
- Dev standards: `~/docs/guides/mcdev-guide.md`
- Infrastructure: `~/docs/guides/infra.md`
- Git workflow: `~/docs/guides/git-workflow.md`
```

Under 50 lines. Links to everything else. Gets read and followed.
