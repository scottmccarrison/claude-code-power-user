---
name: execute
description: >
  Three-tier parallel agent workflow for structured planning and execution.
  Orchestrates Opus, Sonnet, and Haiku agents across recon, planning, building,
  verification, and shipping phases. Use when user says "execute", "let's build
  this", or invokes /execute.
---

# /execute — Three-Tier Parallel Agent Workflow

Use this skill when you're ready to move from discussion into structured
planning and execution.

## Roles

- **Opus** (you): Executive. Orchestrates, synthesizes, decides. Never do grunt work — delegate.
- **Sonnet** (`model: "sonnet"`): Engineers. Implement features with detailed specs.
- **Haiku** (`model: "haiku"`): Interns. Read files, check state, verify output. Fast and cheap.

## Phase 1: Recon (Haiku)

Enter plan mode. Identify what you need to know and send Haiku agents to find out:
- Read current implementations of files that will be changed
- Check git state, open PRs, existing tests
- Look up API contracts, data models, or dependencies

Spawn as **parallel Haiku agents** — one task per agent. Wait for all to return.

## Phase 2: Plan (Opus)

Synthesize Haiku findings into **independent parallel workstreams** for Sonnet agents.

For each workstream:
- **Scope**: 1-2 sentences
- **Files**: Exact paths (confirmed by recon)
- **Changes**: Before/after code snippets
- **Worktree**: `../<repo>-ws<N>`
- **Branch**: `feature/<name>`
- **Commit message**: Ready to use
- **Acceptance criteria**: How to verify

Define integration branch: `integrate/<feature-name>`.

**STOP and wait for user approval.** Do not proceed until explicitly told.

## Phase 3: Build (Sonnet)

1. Create worktrees:
   ```bash
   git worktree add --detach ../<repo>-ws1 main
   git worktree add --detach ../<repo>-ws2 main
   ```
2. Create integration branch: `git branch integrate/<feature> main`
3. Spawn Sonnet agents in parallel (one per workstream)
4. Each agent runs tests before reporting success

## Phase 4: Verify (Haiku)

Spawn parallel Haiku agents to verify each workstream:
- "Read the diff on branch X in worktree Y and report issues"
- "Run tests and report pass/fail with output"
- "Check if [file] contains [expected change]"

## Phase 5: Ship (Opus)

1. Fix flagged issues
2. Merge workstream branches into integration branch
3. Create one PR with summary of all workstreams
4. Auto-merge (unless risky)
5. Close related issues
6. Clean up worktrees
7. List 3-5 manual validation tests for the user

## Critical Rules

- Always use `general-purpose` sub-agents (not `Bash`)
- Worktrees are mandatory for parallel agents modifying the same repo
- Never burn Opus context on exploratory reads — that's Haiku's job
