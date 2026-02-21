# Skills — On-Demand Workflows

## Skills vs. CLAUDE.md vs. Hooks

| Mechanism | When It Loads | Use For |
|-----------|--------------|---------|
| CLAUDE.md | Every session | Persistent rules, style, workflow preferences |
| Hooks | Every matching event | Deterministic automation (lint, block, save) |
| Skills | Only when invoked | Domain-specific workflows loaded on demand |

Skills are the answer to "I need detailed instructions for this specific workflow, but I don't want it cluttering every session." A deploy runbook, a code review checklist, a data migration procedure — these don't belong in CLAUDE.md because they're irrelevant 90% of the time. Skills let you load them exactly when needed.

## Anatomy of a Skill

Skills live in `~/.claude/skills/` (user-level) or `.claude/skills/` (project-level). Each skill is a directory with a `SKILL.md` and optional reference files:

```
~/.claude/skills/
├── execute/
│   └── SKILL.md
├── context-load/
│   ├── SKILL.md
│   └── references/
│       ├── meal-planning.md
│       ├── dev-guide.md
│       └── project-x.md
├── recall/
│   └── SKILL.md
├── remember/
│   └── SKILL.md
└── dbt-review/
    ├── SKILL.md
    └── references/
        ├── conventions-checklist.md
        └── examples.md
```

### SKILL.md Frontmatter

```yaml
---
name: execute
description: >
  Three-tier parallel agent workflow for structured planning and execution.
  Use when user says "execute", "let's build this", or invokes /execute.
machines: [ec2, home-pc]
---
```

- `name`: The skill identifier — becomes `/name` in the CLI
- `description`: Used by Claude to decide when to surface the skill. Write it like you're explaining to a coworker when to reach for it.
- `machines`: Optional — restricts the skill to specific machines (more on this below)

### Reference Files

For skills that need supporting material — checklists, examples, conventions, API contracts — use a `references/` subdirectory. SKILL.md references them explicitly, and they're loaded when the skill runs. Keep SKILL.md focused on workflow steps; put domain knowledge in references.

## Real Skills from Production

### /execute — The Multi-Agent Workflow

The flagship skill. Turns a vague "let's build this" into a structured five-phase execution:

1. **Recon (Haiku)**: Parallel agents read current implementations, check git state, look up dependencies
2. **Plan (Opus)**: Synthesize findings into agent-ready workstreams with exact file paths, code snippets, acceptance criteria
3. **Build (Sonnet)**: Create git worktrees, spawn parallel agents per workstream
4. **Verify (Haiku)**: Verification agents check diffs, run tests, confirm acceptance criteria
5. **Ship (Opus)**: Merge to integration branch, create PR, clean up worktrees

The key constraint: every workstream spec must be complete enough that a Sonnet agent can execute it without exploring or making judgment calls. If the spec has gaps, the Recon phase didn't go deep enough.

Full details in [The /execute Workflow](08-execute-workflow.md).

### /context-load — Topic Switching

Load domain-specific context on demand instead of bloating every session:

```
/context-load meal-planning
/context-load dev-guide
/context-load project-alpha
```

SKILL.md is a simple router:

```markdown
# Context Loader
Load the context matching: **$ARGUMENTS**

## Available Contexts
| Context | Reference |
|---------|-----------|
| meal-planning | `references/meal-planning.md` |
| dev-guide | `references/dev-guide.md` |
| project-x | `references/project-x.md` |

## Instructions
1. Match $ARGUMENTS to a context name (case-insensitive)
2. Read the corresponding reference file
3. Internalize instructions for this conversation
4. Confirm with a brief summary of what was loaded
```

Each reference file contains the full domain context — data models, API contracts, recent decisions, open questions. The meal-planning reference has the current week's plan, ingredient substitution rules, and household preferences. The mcdev reference has Swift conventions, Xcode Cloud config, and the TestFlight release process. None of it loads unless you ask for it.

### /recall and /remember — Memory Access

Thin wrappers around a brain-mem CLI. Simple skills, high value:

```markdown
# /recall
Search memory for: **$ARGUMENTS**

1. Run: `brain-mem search "<$ARGUMENTS>" --top 5`
2. Present results clearly with titles and relevance
3. If no results, suggest alternative search terms
```

```markdown
# /remember
Save to memory: **$ARGUMENTS**

1. Determine an appropriate, specific title
2. Run: `brain-mem save --title "<title>" "<content>"`
3. Confirm what was saved and under what title
```

The value here isn't complexity — it's that you never have to remember the exact CLI syntax mid-session. `/recall last week's deployment decision` just works.

### /dbt-review — Domain-Specific Multi-Agent Review

A work-project skill for reviewing dbt data model PRs. Uses the same tiered pattern as /execute but adapted for SQL/YAML validation:

1. **Scope**: Parse input (PR number, folder path, or model name)
2. **Recon (Haiku)**: Get changed files, check schema.yml coverage, run `dbt parse` for compilation errors
3. **Validate**: Named agents in parallel — conventions checker (against `references/conventions-checklist.md`), cross-reference analyzer (upstream/downstream impacts), dbt compilation runner
4. **Synthesize (Opus)**: Structured report with severity levels (blocker / warning / suggestion)
5. **Optional Execute**: If user approves, spawn Sonnet agents to fix identified issues

The `references/conventions-checklist.md` captures years of team-specific patterns that would be noise in CLAUDE.md but are essential for this workflow.

### /execute-work — Environment-Adapted Workflow

Same five-phase structure as /execute but adapted for work constraints:

- Never creates PRs (the team uses Azure DevOps, not GitHub)
- Reports branch name and suggested PR details for manual creation
- A PreToolUse hook blocks `gh pr create` and `gh pr merge` as a safety net

This is the right pattern when the same conceptual workflow needs different implementation depending on environment. Don't try to make one skill handle both with conditionals — maintain two clean skills and use machine scoping.

## Machine-Scoped Skills

The `machines:` frontmatter field controls where skills appear:

```yaml
machines: [ec2, home-pc]    # Only on personal machines
machines: [work-laptop]      # Only on work machine
```

In practice:
- `/execute` (personal GitHub workflow) — ec2, home-pc
- `/execute-work` (ADO workflow) — work-laptop only
- `/dbt-review` — work-laptop only
- `/recall`, `/remember`, `/context-load` — everywhere

Machine detection reads from `~/.claude-machine`. If the file says `work-laptop`, only work-scoped skills appear. You never have to worry about `/execute` accidentally creating GitHub PRs from a work machine.

## Building Your Own Skills

The trigger: if you've given Claude the same multi-step instructions more than twice, it should be a skill.

Good candidates:
- Deploy workflows (check health, build, push, verify rollout)
- Code review checklists for your team's conventions
- Database migration procedures (backup, apply, verify, rollback plan)
- Incident response runbooks
- Test generation patterns for your codebase

### What Goes Where

**SKILL.md**: Workflow steps only. What to do, in what order, using what tools. Keep it procedural.

**references/**: Domain knowledge. Checklists, examples, API contracts, architecture decisions. This is the material the workflow consumes.

**CLAUDE.md**: Persistent rules that apply everywhere. If it's only relevant for one workflow, it belongs in a skill.

### Testing a New Skill

Invoke it and watch the first few steps. The failure mode for a badly written skill is that Claude starts improvising — filling in steps that weren't specified, making judgment calls that should have been codified. If you see that happening, the skill needs more specificity in the workflow steps or more detail in the reference material.

The goal is a skill that runs the same way every time without requiring you to course-correct.
