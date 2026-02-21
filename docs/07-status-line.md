# Status Line — Situational Awareness

## Why Bother

The default Claude Code status line shows model name and not much else. A custom status line turns the bottom of your terminal into a dashboard — context budget, token burn rate, git branch, session duration. You glance down and know whether you need to `/compact`, whether you're on the right branch, and how fast you're burning through tokens.

## Anatomy of a Status Line

Claude Code pipes JSON to your status line command via stdin:

```json
{
  "model": {"display_name": "Claude Opus 4.6"},
  "cwd": "/home/scott/brain",
  "context_window": {
    "used_percentage": 42.5,
    "context_window_size": 200000,
    "total_input_tokens": 85000,
    "total_output_tokens": 12000
  },
  "cost": {
    "total_duration_ms": 360000
  }
}
```

Your script reads this JSON, formats it, and prints 1-3 lines to stdout.

## Configuration

In `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## A Production Status Line

Three rows: model, git branch, and a metrics bar.

```bash
#!/bin/bash
DATA=$(cat)

# Extract fields with jq
MODEL=$(echo "$DATA" | jq -r '.model.display_name // "unknown"')
CWD=$(echo "$DATA" | jq -r '.cwd // "~"')
USED_PCT=$(echo "$DATA" | jq -r '.context_window.used_percentage // 0')
INPUT_TOKENS=$(echo "$DATA" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$DATA" | jq -r '.context_window.total_output_tokens // 0')
DURATION_MS=$(echo "$DATA" | jq -r '.cost.total_duration_ms // 0')

# Git branch
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "n/a")

# Format tokens (12345 -> 12.3k)
fmt_tokens() {
  echo "$1" | awk '{
    if($1>=1000000) printf "%.1fM",$1/1000000;
    else if($1>=1000) printf "%.1fk",$1/1000;
    else printf "%d",$1
  }'
}

IN_DISPLAY=$(fmt_tokens "$INPUT_TOKENS")
OUT_DISPLAY=$(fmt_tokens "$OUTPUT_TOKENS")

# Burn rate (input tokens per minute)
if [ "$DURATION_MS" -gt 0 ] 2>/dev/null; then
  BURN_RATE=$(awk "BEGIN {printf \"%.0f\", $INPUT_TOKENS / ($DURATION_MS / 60000)}")
  BURN_DISPLAY=$(fmt_tokens "$BURN_RATE")
else
  BURN_DISPLAY="0"
fi

# Duration
SECS=$((DURATION_MS / 1000))
MINS=$((SECS / 60))
HRS=$((MINS / 60))
if [ "$HRS" -gt 0 ]; then
  TIME="${HRS}h $((MINS % 60))m"
elif [ "$MINS" -gt 0 ]; then
  TIME="${MINS}m $((SECS % 60))s"
else
  TIME="${SECS}s"
fi

# Color based on context usage
PCT_INT=${USED_PCT%.*}
if [ "${PCT_INT:-0}" -ge 80 ]; then
  CTX_COLOR='\033[31m'  # Red
elif [ "${PCT_INT:-0}" -ge 50 ]; then
  CTX_COLOR='\033[33m'  # Yellow
else
  CTX_COLOR='\033[32m'  # Green
fi

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'

# Output
echo -e "${BOLD}${CYAN}${MODEL}${RESET}"
echo -e "${DIM}branch:${RESET} ${GREEN}${BRANCH}${RESET}"
echo -e "${CTX_COLOR}${PCT_INT:-0}%${RESET}  ${DIM}in:${RESET}${IN_DISPLAY}  ${DIM}out:${RESET}${OUT_DISPLAY}  ${DIM}burn:${RESET}${BURN_DISPLAY}${DIM}/m${RESET}  ${DIM}time:${RESET}${TIME}"
```

## What Each Metric Tells You

| Metric | What It Means | Action |
|--------|--------------|--------|
| **Context %** (green/yellow/red) | How full your context window is | `/compact` when yellow, definitely at red |
| **in:** | Total input tokens this session | Tracks cumulative cost |
| **out:** | Total output tokens this session | Tracks how much Claude has generated |
| **burn:** | Input tokens per minute | High burn = lots of file reading or agent output |
| **time:** | Session duration | Rough session awareness |
| **branch** | Current git branch | Catches "wait, I'm on main" moments |

## Windows Compatibility

Windows (Git Bash) often lacks `jq`. Use a Python script instead:

```python
#!/usr/bin/env python3
import json, sys

data = json.load(sys.stdin)
model = data.get("model", {}).get("display_name", "unknown")
pct = data.get("context_window", {}).get("used_percentage", 0)
branch = "n/a"  # Use subprocess to get git branch

print(f"{model}")
print(f"ctx: {pct:.0f}%")
```

Deploy the right script per machine via `setup.sh` and the `machines/<name>/` directory.

## Tips

- Keep the status line fast — it runs on every turn. No network calls, no slow git operations.
- Use ANSI colors for at-a-glance readability. Red context percentage catches your eye.
- The burn rate metric helps identify sessions where you're doing too much exploration in the main thread (should be delegating to Haiku).
- Three rows is the sweet spot. More than that and it steals too much screen space.
