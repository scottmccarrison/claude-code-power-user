# Claude Code Power User Guide

A comprehensive guide to maximizing Claude Code — hooks, memory, sub-agents, portable config, and multi-tier agent workflows.

**This isn't a theoretical framework.** Every pattern here was built and refined while shipping real software (an iOS app + Python backend through 8 major releases). Patterns that didn't survive contact with reality were cut.

## Who This Is For

You already use Claude Code. You want to go from "it helps me write code" to "it's my engineering team." You're willing to invest in configuration that compounds over time.

## Table of Contents

1. [CLAUDE.md — The Foundation](docs/01-claude-md.md)
2. [Hooks — Deterministic Automation](docs/02-hooks.md)
3. [Memory — Persistent Context Across Sessions](docs/03-memory.md)
4. [Sub-Agents — Parallel Execution at Scale](docs/04-sub-agents.md)
5. [Skills — On-Demand Workflows](docs/05-skills.md)
6. [Portable Configuration — Multi-Machine Setup](docs/06-portable-config.md)
7. [Status Line — Situational Awareness](docs/07-status-line.md)
8. [Putting It All Together — The /execute Workflow](docs/08-execute-workflow.md)
9. [Honest Self-Assessment — Where This Sits](docs/09-assessment.md)

## Quick Start

If you want to adopt these patterns incrementally, here's the recommended order:

1. **Write a good CLAUDE.md** — highest ROI, zero setup cost
2. **Add a PostToolUse lint hook** — catch errors automatically
3. **Add a PreToolUse guard hook** — prevent commits to main
4. **Set up a status line** — know your context budget
5. **Create your first skill** — automate your most common workflow
6. **Build a memory system** — stop losing context between sessions
7. **Formalize your agent workflow** — the /execute pattern

## Philosophy

Three principles guide this setup:

1. **Hooks over instructions.** CLAUDE.md is advisory — the model can ignore it. Hooks are deterministic. If something must happen every time with zero exceptions, make it a hook.

2. **Delegate aggressively.** The main conversation context is expensive (Opus-level). Burn it on decisions, not research. Haiku agents are cheap — spin up as many as needed for exploration and verification.

3. **Portable over bespoke.** Configuration should work on any machine with a single `setup.sh`. Machine-specific behavior comes from overrides, not forks.

## What's NOT Here

- **Toy examples.** Every hook, skill, and pattern is production code extracted from a real setup.
- **Comprehensive Anthropic docs rehash.** Read the [official docs](https://docs.anthropic.com/en/docs/claude-code/overview) for basics. This guide covers what you do *after* you've read them.
- **Claims of being the best setup possible.** See the [honest assessment](docs/09-assessment.md) for where this ranks and what the community ceiling looks like.

## License

MIT — use whatever's useful, ignore the rest.
