# Memory — Persistent Context Across Sessions

## The Problem

Claude Code's context resets every session. Compaction loses detail. You repeat yourself explaining the same architecture, the same deployment conventions, the same decisions you made three months ago. A debugging insight that took an hour to reach vanishes the moment the session ends.

The solution is a layered memory system. Each layer handles a different scope and access pattern.

## Three Layers of Memory

### Layer 1: MEMORY.md (Built-In)

Claude Code auto-loads `~/.claude/projects/<project>/memory/MEMORY.md` at session start. The first 200 lines are injected into context automatically — no configuration needed.

Use it for: infrastructure tables, project indexes, version history, quick-reference that you'd otherwise re-explain every session.

```markdown
# Memory

## Infrastructure Quick Reference
| System | Access | Deploy |
|--------|--------|--------|
| **Brain API EC2** | Tailscale `brain-api-1` | `ssh ... && git pull && systemctl restart` |
| **Dev EC2** | `dev.mccarrison.me` | N/A |

## Projects
| Repo | Stack | Notes |
|------|-------|-------|
| **mchome-ios** | Swift, Xcode Cloud | iOS app |
| **brain** | Python/FastAPI + PostgreSQL | Backend API |

## v1.9 — Plants (Complete, 2026-02-16)
Backend: `plants` + `plant_waterings` tables, `/api/plants` CRUD.
iOS: `PlantViewModel`, `PlantListView`, full offline mutation queue.
```

**The 200-line cap is real.** Past line 200, nothing loads. Keep MEMORY.md as an index, not a notebook:

- Move detailed content to separate topic files (`~/docs/guides/<topic>.md`)
- Remove entries for completed work aggressively
- Don't duplicate what's already in CLAUDE.md
- Reference external files rather than inlining their content

### Layer 2: External Memory Backend (Brain-Mem)

MEMORY.md is too small, not searchable, and tied to one machine. The real solution is an external memory store: PostgreSQL + pgvector on a persistent server, with a CLI tool that any machine can hit.

```bash
# Search
brain-mem search "pantry API endpoints" --top 5

# Save manually
brain-mem save --title "Decided to use LATERAL JOIN for last_watered_at" \
  "Using LATERAL JOIN instead of subquery for plant watering — cleaner query plan"
```

The architecture:

```
Claude Code session
    ├── Stop hook      → save-to-brain-mem.py → POST /api/memories  (per-turn)
    ├── SessionEnd hook → save-to-brain-mem.py → POST /api/memories  (session summary)
    └── /recall skill  → brain-mem search      → GET /api/memories/search
```

Why external beats file-based:
- **Search** (semantic + full-text) vs. grepping a flat file
- **Cross-machine** — EC2, home PC, work laptop all share the same memory
- **Structured metadata** — action types, session IDs, machine names, tags
- **No git conflicts** — writes go directly to the database

After several months of active use, you accumulate 1000+ memories. The search quality is what makes retrieval useful — without it, you're back to manually scanning files.

### Layer 3: Transcript Archives

Raw JSONL transcripts archived to `~/.claude/archives/YYYY-MM-DD/<session-id>.jsonl`. Every tool call, every response, every file read — complete audit log.

This layer isn't searchable directly. It's disaster recovery: "what exactly did Claude do to break that migration?" You don't query it regularly; you're glad it's there when you need it.

SessionEnd hook handles archival automatically.

## The Auto-Save Hook

The critical insight: **zero manual effort**. Hooks wire memory saves to Claude's lifecycle events. You never have to remember to save.

`save-to-brain-mem.py` runs on Stop (per-turn) and SessionEnd (session summary).

### Per-Turn Saves (Stop event)

1. Read the transcript JSONL
2. Extract last user message + assistant response
3. Skip trivial exchanges (acknowledgments under 20 chars)
4. Classify action type: `debug`, `deploy`, `implement`, `configure`, `refactor`, `review`, `research`
5. Extract topics via regex — tool names, infrastructure terms, repo names, file paths
6. Build title: `[action] first line of user message`
7. POST to Brain API with content, title, tags, session_id, machine name

### Session Summary (SessionEnd event)

1. Read full transcript
2. Count turns, calculate duration, identify repos from working directories
3. Build action summary: `"implement: 5 turns, debug: 3 turns"`
4. Extract all topics and files modified
5. Condense user messages (first line of each, capped at 15)
6. Assemble structured summary (capped at 4000 chars)
7. Archive raw JSONL to disk
8. POST summary to Brain API

### Key Design Decisions

**Silent fail on all API errors.** The hook must never block Claude. If the memory backend is down, Claude continues working. A failed memory save is annoying; a broken hook that hangs the session is catastrophic.

**Stdlib only, no pip dependencies.** The hook must work on any machine without setup. Don't import `requests`. Use `urllib.request`.

**Action classification is regex-based, not LLM-based.** Fast, deterministic, no API cost. Pattern-match on user message keywords: "fix", "deploy", "add", "refactor", "how does", "what is".

**Cross-platform.** Home directory resolution, path handling, and JSONL parsing should work on Linux and Windows without branching on `sys.platform`.

## Skills for Manual Memory Access

### /remember

```
/remember The production database connection pool is capped at 10 — higher values cause OOM on the t3.small
```

Saves to brain-mem with an auto-generated title. Use for one-off decisions that won't appear in a natural turn-by-turn save.

### /recall

```
/recall database connection pool
```

Searches brain-mem, returns top 5 results with relevance scores. Use at session start when picking up a task you haven't touched in weeks.

Wire both as skills in CLAUDE.md so they're available from `/` in any session.

## Building Your Own Memory System

If you don't want to run PostgreSQL on EC2, simpler options work:

**SQLite + FTS5** — local file, no server, full-text search built in. Single file you can back up with rsync. Loses cross-machine access but gains simplicity.

**JSON file with grep** — simplest possible implementation. Append JSON objects to a file, grep to search. Degrades as volume grows but works well under a few hundred entries.

**Obsidian vault** — if you're already in Obsidian, save memories as dated markdown files. Obsidian's search handles retrieval. Reasonable choice if you live in the app already.

The backend doesn't matter as much as the hooks. Auto-saving on Stop + SessionEnd means zero manual effort. Whatever storage you choose, wire it to hooks first. You can migrate the backend later; building the habit of manual saving doesn't scale.

## Memory Hygiene

**Search before saving manually.** The auto-save hook generates a lot of entries. Before saving a decision manually, search for it — it may already be there from a prior turn.

**Manual saves are for synthesized insights.** The hook captures raw turn-by-turn context well. What it misses: high-level architectural decisions, lessons learned across multiple sessions, "we tried X and it failed because Y." Those are worth a manual `/remember`.

**Prune MEMORY.md regularly.** Completed feature work, superseded infrastructure, old version history — remove it. The 200-line cap means every line costs something. A table of 10 completed features from six months ago is wasted space.

**Tag consistently.** Action type + topic + repo is enough. `debug postgres` beats `weird bug with the database thing from that one session`. You're building a corpus you'll search months from now.

## What This Looks Like in Practice

Session start on a feature you haven't touched in a month:

```
/recall pantry API offline mutations
```

Returns 3-4 entries: the original implementation decision, a bug you hit with optimistic updates, the fix. You're oriented in 30 seconds instead of re-reading code for 10 minutes.

Session end is automatic. The hook fires, classifies your turns, extracts the topics, posts the summary. Next month when you return, `/recall` has it.

The system pays for itself after the first time it saves you from re-debugging something you already solved.
