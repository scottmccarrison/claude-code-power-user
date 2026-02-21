# Sub-Agents — Parallel Execution at Scale

## The Mental Model

Think of it as a company:
- **Opus** = Executive. Makes decisions, orchestrates, synthesizes. Never does grunt work.
- **Sonnet** = Senior engineer. Implements features with detailed specs. Writes code, runs tests.
- **Haiku** = Intern. Fast, cheap, focused on one thing. Reads files, checks state, verifies output.

The critical insight: **the main conversation context is your most expensive resource.** Every exploratory file read, every grep, every "let me check the current implementation" burns Opus-tier tokens. Delegate aggressively.

## The 3-Tool-Call Rule

Before doing ANY research yourself, ask: "Will this take 3+ tool calls?"
- **Yes** → Spawn a Haiku agent
- **No** → Do it directly (1-2 quick Grep/Glob calls are fine)

This single rule prevents the most common context waste pattern: Opus spending 20 turns reading files that Haiku could have summarized in one shot.

## When to Use Each Tier

| Task | Agent | Why |
|------|-------|-----|
| "Find all usages of OldAPIClient" | Haiku | Pure exploration, no judgment needed |
| "Read the current auth implementation and summarize it" | Haiku | Research that produces a summary |
| "Implement the logout button per this spec" | Sonnet | Implementation with clear requirements |
| "Create the pantry CRUD endpoints following the notes pattern" | Sonnet | Implementation requiring pattern matching |
| "Is this PR safe to auto-merge?" | Opus (you) | Requires judgment and risk assessment |
| "Design the architecture for weather integration" | Opus (you) | Requires cross-cutting reasoning |

## Git Worktrees: Mandatory for Parallel Agents

If multiple agents modify the same repo, they WILL corrupt each other's branches and staging area. Learned this the hard way.

```bash
# Before launching N parallel agents:
git worktree add --detach ../reponame-ws1 main
git worktree add --detach ../reponame-ws2 main

# Point each agent at its own worktree path
# After merging, clean up:
git worktree remove ../reponame-ws1
git worktree remove ../reponame-ws2
```

Why `--detach`: You can't check out `main` in multiple worktrees simultaneously. Detach creates an anonymous branch from main.

Why `general-purpose` agent type (not `Bash`): Bash agents only have the Bash tool. `sed` edits get blocked by permission settings. `general-purpose` agents have Edit/Write/Read + Bash — everything they need to implement changes.

## Agent-Ready Plans

A plan is "agent-ready" when a Sonnet agent can execute it **without exploring or making judgment calls**. This means exact file paths, before/after code snippets, and clear acceptance criteria.

### Good Plan (Agent-Ready)
```markdown
## Workstream: Add Logout Button

**Files to modify:**
1. `my-ios-app/Views/Settings/SettingsView.swift` (line ~45)
2. `my-ios-app/ViewModels/SettingsViewModel.swift`

**Change in SettingsView.swift — add after line 45:**
Button(action: { viewModel.logout() }) {
    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
}
.foregroundColor(.red)

**Git:** Branch `feature/logout-button`, commit "Add logout button to Settings tab"
**Acceptance:** Button appears in Settings, tapping clears auth token, existing tests pass
```

### Bad Plan (Agent-Hostile)
```markdown
## Add Logout
- Add a logout button somewhere in settings
- Make it clear auth when clicked
- Style it appropriately
```

The bad plan requires the agent to explore, decide placement, guess at implementation, and make style judgments. That's Opus work disguised as Sonnet work. The agent will either make wrong assumptions or stall asking questions.

## Verification: Trust But Verify

After agents complete, don't just read their final message. Agent summaries are narratives, not proof. Spawn Haiku verification agents:

```
"Read the diff on branch feature/X in worktree ../repo-ws1 and report any issues
or deviations from the spec"
```

```
"Run the test suite in /path/to/repo and report pass/fail with any error output"
```

```
"Check if SettingsView.swift contains a logout button — read the file and report back"
```

One verification task per Haiku agent. They're cheap — spin up as many as needed.

## Common Pitfalls

### 1. Spawning Opus sub-agents
Unless you need cross-cutting architectural reasoning in a sub-agent, Sonnet is sufficient for implementation. Save Opus for the main thread where it can see everything.

### 2. Over-scoping Haiku agents
Haiku agents should do ONE thing. Don't ask a Haiku agent to "read these 5 files and then implement the change." Research is Haiku. Implementation is Sonnet. Mixing them wastes both.

### 3. Forgetting worktrees
If you see branch contamination or merge conflicts between parallel agents, you forgot worktrees. Stop, create them, re-launch. Don't try to untangle the mess — it's not worth it.

### 4. Not verifying
Always verify with at least a Haiku agent reading the actual diff. A confident agent summary that says "all done" can still have missed a file or gotten the implementation subtly wrong.

### 5. Launching agents for trivial tasks
A single Grep call doesn't need a sub-agent. A two-line config change doesn't need a sub-agent. Use the 3-tool-call rule and save the overhead for tasks that actually benefit.

## Cost Awareness

Sub-agents multiply token usage. Before launching, think:
- 1-2 tool calls → do it directly
- Parallel agents → briefly state what each does and why parallelization is worth it
- Borderline cases → ask the user

Machine-specific overrides in `CLAUDE.md` can enforce cost rules:
```markdown
# Machine Overrides (home-pc)
**NEVER use Opus** sub-agents — cost restriction.
- Sonnet: planning, implementation, refactoring
- Haiku: ALL research, exploration, verification
```

The ROI calculation is simple: parallel Sonnet agents finishing a 4-workstream feature in one shot beats sequential Opus doing it over 40 turns. But a Sonnet agent reading one file to answer a quick question is waste.
