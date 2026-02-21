# Putting It All Together — The /execute Workflow

## Overview

`/execute` is the culmination of every pattern in this guide — CLAUDE.md rules, sub-agent tiers, worktree isolation, Haiku verification, and auto-merge workflows. It's a formalized 5-phase skill that turns "implement this feature" into a structured, parallelized, verified delivery pipeline.

## The Five Phases

```
Phase 1: Recon (Haiku)     → Gather context in parallel
Phase 2: Plan (Opus)       → Synthesize into agent-ready workstreams
Phase 3: Build (Sonnet)    → Implement in isolated worktrees
Phase 4: Verify (Haiku)    → Check every diff against the spec
Phase 5: Ship (Opus)       → Merge, PR, deploy, clean up
```

## Phase 1: Recon

Before writing any plan, identify what you need to know and send Haiku agents to find out. Each agent gets one focused task:

```
Agent 1: "Read /home/scott/brain/app/routes/meals.py and report its
          current route definitions and patterns"

Agent 2: "Check git state of my-ios-app repo: current branch, dirty
          files, open PRs"

Agent 3: "Read the Plant model in my-ios-app and report its properties
          and SwiftData cache structure"

Agent 4: "List all tests in brain/tests/ that touch the plants module"
```

Launch all in parallel. Wait for all to return before proceeding.

**Why not do this yourself?** Each of these is 3-5 tool calls. Doing four of them yourself burns 15-20 Opus turns on pure research. Haiku handles it in parallel for a fraction of the cost and context.

## Phase 2: Plan

Synthesize Haiku findings into workstreams. Each workstream must be **agent-ready** — a Sonnet agent should be able to execute it without exploring or making judgment calls.

For each workstream, specify:

| Element | Example |
|---------|---------|
| **Scope** | "Add CRUD endpoints for plant watering history" |
| **Files** | `brain/app/routes/plants.py`, `brain/app/models/plant.py` |
| **Changes** | Before/after code snippets or precise descriptions |
| **Worktree** | `../brain-ws1` |
| **Branch** | `feature/plant-watering-endpoints` |
| **Commit message** | "Add watering history endpoints for plants" |
| **Acceptance criteria** | "4 new routes, tests pass, matches existing pattern" |

Define the integration branch: `integrate/v1.9-plants`

**Present the plan and stop.** Wait for user approval. Don't proceed until explicitly told to execute. Expect feedback — one revision per round is the norm.

## Phase 3: Build

On approval:

### 1. Create worktrees
```bash
git worktree add --detach ../brain-ws1 main
git worktree add --detach ../brain-ws2 main
git worktree add --detach ../my-ios-app-ws1 main
```

### 2. Create the integration branch
```bash
git branch integrate/v1.9-plants main
```

### 3. Spawn Sonnet agents in parallel

Each agent gets:
- Its worktree path (isolated filesystem)
- Branch to create inside the worktree
- Full implementation spec from Phase 2
- Instruction to run tests before reporting success

```
Agent A (Sonnet, ../brain-ws1):     Backend CRUD endpoints
Agent B (Sonnet, ../brain-ws2):     Backend tests
Agent C (Sonnet, ../my-ios-app-ws1): iOS model + API service + ViewModel
```

Critical rules:
- Always `general-purpose` agent type, never `Bash`
- Each agent works in its own worktree — no shared state
- If tests fail after 3 attempts, report failure with diagnostics (don't loop)

## Phase 4: Verify

Do NOT read all the modified files yourself. Spawn Haiku verification agents:

```
Verify Agent 1: "Read the diff on branch feature/plant-endpoints
                 in ../brain-ws1. Report any issues or deviations
                 from spec."

Verify Agent 2: "Run pytest in ../brain-ws1 and report pass/fail
                 with any error output."

Verify Agent 3: "Check if PlantView.swift in ../my-ios-app-ws1
                 contains the watering history list and quick-water
                 buttons."
```

One task per Haiku agent. They're cheap — use as many as needed.

## Phase 5: Ship

Review verification reports. Only dig deep on flagged issues.

### 1. Fix issues
If Haiku flags problems, either fix them yourself (trivial) or re-launch a Sonnet agent with a targeted fix spec.

### 2. Merge workstream branches
```bash
git checkout integrate/v1.9-plants
git merge feature/plant-endpoints
git merge feature/plant-tests
git merge feature/plant-ios-model
```
Resolve trivial conflicts automatically. Ask the user on non-trivial ones.

### 3. Create one PR
```bash
gh pr create --title "v1.9: Plant tracking with watering schedules" \
  --body "$(cat <<'EOF'
## Summary
- Backend: plants + plant_waterings tables, CRUD endpoints
- iOS: Plant model, SwiftData cache, PlantViewModel, PlantListView
- Full offline mutation queue support

Closes #282
EOF
)"
```

### 4. Auto-merge (if safe)
Standard CRUD following existing patterns? Auto-merge. Auth changes or schema migrations? Ask first.

### 5. Clean up
```bash
git worktree remove ../brain-ws1
git worktree remove ../brain-ws2
git worktree remove ../my-ios-app-ws1
```

### 6. User validation tests
End with 3-5 specific manual tests:
- Open the Plants tab and verify the list loads
- Add a new plant and confirm it persists
- Tap the water button and verify the timestamp updates
- Kill the app and reopen — data should still be there
- Toggle airplane mode and verify offline mutations queue

## Environment Variants

### /execute (personal projects)
Full workflow: creates PRs via `gh`, auto-merges, closes issues.

### /execute-work (work laptop)
Same phases but Phase 5 differs:
- Never creates PRs (Azure DevOps, not GitHub)
- Reports integration branch name + suggested PR title/body
- User creates the PR manually in ADO
- PreToolUse hook blocks `gh pr create/merge` as a safety net

## When to Use /execute

Good candidates:
- Multi-file features spanning backend + frontend
- Features with 2+ independent workstreams
- Anything where parallelization saves significant time

Overkill for:
- Single-file bug fixes
- One-endpoint additions
- Config changes

## Lessons Learned

1. **Worktrees are non-negotiable.** Without them, agents corrupt each other's branches. Learned this the hard way in the first batch of parallel agents.

2. **Recon before planning.** Plans based on assumptions waste Sonnet tokens when agents discover the code doesn't look how you expected.

3. **Verification is not optional.** Agent summaries say "done, all tests pass" but the tests might not have actually run. Always verify.

4. **One integration branch, one PR.** Don't create N PRs for N workstreams. Merge locally, create one clean PR. Easier to review, easier to revert.

5. **User approval is a feature.** The pause between Phase 2 and Phase 3 catches bad plans before they become bad code.
