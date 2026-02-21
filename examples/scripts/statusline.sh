#!/bin/bash
# Claude Code status line — 3 rows
# Shows: model name, git branch, context%/tokens/burn-rate/time
#
# Configuration in settings.json:
# {
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline.sh"
#   }
# }

DATA=$(cat)

# Extract fields
MODEL=$(echo "$DATA" | jq -r '.model.display_name // "unknown"')
CWD=$(echo "$DATA" | jq -r '.cwd // "~"')
USED_PCT=$(echo "$DATA" | jq -r '.context_window.used_percentage // 0')
CTX_SIZE=$(echo "$DATA" | jq -r '.context_window.context_window_size // 200000')
INPUT_TOKENS=$(echo "$DATA" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$DATA" | jq -r '.context_window.total_output_tokens // 0')
DURATION_MS=$(echo "$DATA" | jq -r '.cost.total_duration_ms // 0')

# Git branch
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "n/a")

# Format context window size (200000 -> 200k)
CTX_DISPLAY=$(echo "$CTX_SIZE" | awk '{if($1>=1000) printf "%.0fk",$1/1000; else print $1}')

# Format tokens (12345 -> 12.3k)
fmt_tokens() {
  echo "$1" | awk '{if($1>=1000000) printf "%.1fM",$1/1000000; else if($1>=1000) printf "%.1fk",$1/1000; else printf "%d",$1}'
}
IN_DISPLAY=$(fmt_tokens "$INPUT_TOKENS")
OUT_DISPLAY=$(fmt_tokens "$OUTPUT_TOKENS")

# Burn rate (input tokens/min)
if [ "$DURATION_MS" -gt 0 ] 2>/dev/null; then
  BURN_RATE=$(awk "BEGIN {printf \"%.0f\", $INPUT_TOKENS / ($DURATION_MS / 60000)}")
  BURN_DISPLAY=$(fmt_tokens "$BURN_RATE")
else
  BURN_DISPLAY="0"
fi

# Format duration
SECS=$((DURATION_MS / 1000))
MINS=$((SECS / 60))
HRS=$((MINS / 60))
if [ "$HRS" -gt 0 ]; then
  TIME_DISPLAY="${HRS}h $((MINS % 60))m"
elif [ "$MINS" -gt 0 ]; then
  TIME_DISPLAY="${MINS}m $((SECS % 60))s"
else
  TIME_DISPLAY="${SECS}s"
fi

# Colors
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'
BOLD='\033[1m'

# Context color based on usage
PCT_INT=${USED_PCT%.*}
if [ "${PCT_INT:-0}" -ge 80 ]; then
  CTX_COLOR=$RED
elif [ "${PCT_INT:-0}" -ge 50 ]; then
  CTX_COLOR=$YELLOW
else
  CTX_COLOR=$GREEN
fi

# Output: 3 rows
echo -e "${BOLD}${CYAN}${MODEL}${RESET}"
echo -e "${DIM}branch:${RESET} ${GREEN}${BRANCH}${RESET}"
echo -e "${CTX_COLOR}${PCT_INT:-0}%${RESET}${DIM}/${RESET}${CTX_DISPLAY}  ${DIM}in:${RESET}${IN_DISPLAY}  ${DIM}out:${RESET}${OUT_DISPLAY}  ${DIM}burn:${RESET}${BURN_DISPLAY}${DIM}/m${RESET}  ${DIM}time:${RESET}${TIME_DISPLAY}"
