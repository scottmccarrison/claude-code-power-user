# Example Skills

Production skills extracted from a real Claude Code setup.

## What's Here

| Skill | Purpose |
|-------|---------|
| `execute/` | 5-phase multi-agent workflow (Recon → Plan → Build → Verify → Ship) |
| `context-load/` | On-demand domain context loading |

## Installation

Copy skill directories to `~/.claude/skills/` or `.claude/skills/` in your project.

## Creating Your Own

1. Create a directory under `~/.claude/skills/<name>/`
2. Add `SKILL.md` with YAML frontmatter (`name`, `description`)
3. Optionally add `references/` for detailed context
4. The skill becomes available as `/<name>` in Claude Code

See [the skills guide](../../docs/05-skills.md) for detailed patterns.
