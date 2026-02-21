# Portable Configuration — Multi-Machine Setup

## The Problem

You use Claude Code on multiple machines. Home PC, EC2 dev server, work laptop. Each has different paths, tools, and constraints. But you want the same skills, hooks, memory, and CLAUDE.md everywhere — without manually maintaining three diverging configs.

The solution: one git repo as the single source of truth.

---

## The Architecture

```
docs/
├── CLAUDE.md                    # Universal instructions
├── setup.sh                     # Bootstrap script
├── claude/
│   ├── skills/                  # Shared skills
│   ├── hooks/                   # Shared hook scripts
│   ├── agents/                  # Custom agent definitions
│   └── memory/
│       └── MEMORY.md            # Shared memory index
├── machines/
│   ├── home-pc/
│   │   ├── settings.json        # Machine-specific Claude settings
│   │   ├── overrides.md         # Machine-specific CLAUDE.md additions
│   │   └── statusline.sh
│   ├── ec2/
│   │   ├── settings.json
│   │   ├── overrides.md
│   │   └── statusline.sh
│   └── work-laptop/
│       ├── settings.json
│       ├── overrides.md
│       └── statusline.py        # Python version — no jq on Windows
├── guides/                      # Reference docs (loaded by skills)
│   ├── git-workflow.md
│   ├── infra.md
│   └── mcdev-guide.md
└── scripts/
    └── brain-mem                # CLI tool for memory
```

---

## setup.sh — One Command Bootstrap

Run `./setup.sh <machine-name>` on a new machine. It handles everything:

1. Write machine identity to `~/.claude-machine`
2. Symlink (or copy on Windows) skills, hooks, agents, memory into `~/.claude/`
3. Deploy machine-specific `settings.json` and status line
4. Concatenate universal `CLAUDE.md` + machine overrides → `~/CLAUDE.md`
5. Install brain-mem CLI to `~/.local/bin/`

```bash
#!/usr/bin/env bash
set -euo pipefail

MACHINE="${1:-}"
if [[ ! "$MACHINE" =~ ^(ec2|work-laptop|home-pc)$ ]]; then
    echo "Usage: ./setup.sh <ec2|work-laptop|home-pc>"
    exit 1
fi

DOCS="$(cd "$(dirname "$0")" && pwd)"

# Platform detection
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    Darwin*)               PLATFORM="macos" ;;
    *)                     PLATFORM="linux" ;;
esac

link_or_copy() {
    if [ "$PLATFORM" = "windows" ]; then
        cp -rf "$1" "$2"
    else
        ln -sf "$1" "$2"
    fi
}

# Write machine identity
echo "$MACHINE" > ~/.claude-machine

# Link shared Claude config
mkdir -p ~/.claude
link_or_copy "$DOCS/claude/skills"   ~/.claude/skills
link_or_copy "$DOCS/claude/hooks"    ~/.claude/hooks
link_or_copy "$DOCS/claude/agents"   ~/.claude/agents
link_or_copy "$DOCS/claude/memory"   ~/.claude/memory

# Deploy machine-specific settings
cp "$DOCS/machines/$MACHINE/settings.json" ~/.claude/settings.json
link_or_copy "$DOCS/machines/$MACHINE/statusline.sh" ~/.claude/statusline.sh

# Build CLAUDE.md = universal + overrides
cat "$DOCS/CLAUDE.md" "$DOCS/machines/$MACHINE/overrides.md" > ~/CLAUDE.md

# Install brain-mem CLI
mkdir -p ~/.local/bin
link_or_copy "$DOCS/scripts/brain-mem" ~/.local/bin/brain-mem
chmod +x ~/.local/bin/brain-mem

echo "Done. Configured for: $MACHINE"
```

Key decisions baked in:

- **Symlinks on Linux/Mac, copies on Windows** — Windows symlinks require admin mode
- **Machine identity in a file** (`~/.claude-machine`) rather than hostname — reliable across VPNs and containers
- **CLAUDE.md is concatenated**, not referenced — simpler for Claude to consume, no import indirection
- **Secrets are never in the repo** — `.env`, API keys, SSH keys are manual setup per machine

---

## Machine Overrides

Each machine gets an `overrides.md` appended to the universal CLAUDE.md. This is where per-environment policy lives:

**`machines/home-pc/overrides.md`:**
```markdown
# Home PC Overrides

## Sub-Agent Model Strategy
**NEVER use Opus** — cost restriction in effect.
- Sonnet: implementation, planning
- Haiku: ALL research, exploration, verification

## MCP Servers
- **db** MCP: read-only SQL to brain Postgres
- **github** MCP: structured GitHub API
```

**`machines/work-laptop/overrides.md`:**
```markdown
# Work Laptop Overrides

## Sub-Agent Model Strategy
- Opus: architecture, complex review
- Sonnet: implementation with clear specs
- Haiku: lookups, exploration

## Azure DevOps
Before using ADO MCP tools, read `guides/azure-devops-config.md`.
PR creation must be done manually — do not use ADO MCP for that.
```

This gives you per-machine control over:
- **Cost** — no Opus on personal machines, full tier at work
- **MCP servers** — different integrations per environment
- **Dangerous operation restrictions** — tighter guardrails on machines with production access

---

## Machine-Specific Settings

`settings.json` controls hooks, permissions, and MCP plugins per machine:

**`machines/home-pc/settings.json`:**
```json
{
  "permissions": {
    "allow": ["Bash(gh *)"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/block-main-commit.sh"}]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Work laptop adds an extra hook blocking accidental ADO PR creation:
```json
"PreToolUse": [
  {"matcher": "Bash", "hooks": [
    {"type": "command", "command": "~/.claude/hooks/block-main-commit.sh"},
    {"type": "command", "command": "~/.claude/hooks/block-ado-pr.sh"}
  ]}
]
```

The hook scripts themselves live in the shared `claude/hooks/` directory and are symlinked everywhere — but `settings.json` controls which ones are active on each machine.

---

## What Lives Where

| What | Shared (in repo) | Machine-specific |
|------|-----------------|-----------------|
| CLAUDE.md | Universal base | + `overrides.md` appended |
| Skills | All shared | `machines:` frontmatter filters which activate |
| Hook scripts | Shared | `settings.json` controls which are active |
| MEMORY.md | Shared via symlink | — |
| brain-mem database | Central (EC2) | — |
| Secrets (`.env`, keys) | Never | Manual per machine |
| Status line | — | In `machines/<name>/` |
| MCP config | — | In `settings.json` per machine |

---

## Syncing

The docs repo syncs via git. CLAUDE.md instructs Claude to pull at session start and push at session end if anything changed:

```bash
# Session start (CLAUDE.md instructs this)
git -C ~/docs pull --ff-only

# Session end (when docs were modified)
cd ~/docs && git add -A && git commit -m "sync: <description>" && git push
```

brain-mem writes to a central database (not files), so there are no git conflicts on memory. The only things that change in the repo are MEMORY.md, guides, and meal plans — low-frequency, low-conflict.

---

## Security Considerations

This setup optimizes for convenience. The tradeoffs:

- API keys are in environment variables or `.env` files — not in the repo
- The brain-mem API is behind Cloudflare with an API key
- SSH keys are per-machine, never shared
- The docs repo is private on GitHub

For higher security needs:
- **chezmoi + Age** for encrypted secret management across machines
- **Pre-commit hooks** scanning for accidentally committed secrets (`git-secrets`, `trufflehog`)
- **Separate repos** for sensitive config (MCP credentials, work-specific rules) vs. shareable config (skills, guides)

---

## Building Your Own

Don't try to build this all at once. It evolved over months:

1. Create a `docs` repo with your `CLAUDE.md` and a `machines/` directory
2. Write a minimal `setup.sh` that symlinks `~/.claude/` contents and writes `~/.claude-machine`
3. Add machine overrides as real differences emerge — not speculatively
4. Add hooks and skills when you find yourself repeating the same corrections

The structure above is the end state. Start with three files and grow it from there.
