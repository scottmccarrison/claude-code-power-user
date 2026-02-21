#!/bin/bash
# SessionStart hook: auto-surface project context
# Matcher: "" (runs on every session start)
#
# Injects machine identity, git state, open PRs, and brain-mem
# memories into Claude's context at the start of every session.

INPUT=$(cat)
CWD=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('cwd',''))" <<< "$INPUT" 2>/dev/null)

# Machine identity (prefer marker file over hostname)
if [ -f "$HOME/.claude-machine" ]; then
    MACHINE=$(cat "$HOME/.claude-machine")
else
    MACHINE=$(hostname)
fi
echo "Machine: $MACHINE"
echo ""

# Git state (if in a repo)
if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    PROJECT_DIR=$(basename "$CWD")
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    echo "Project: $PROJECT_DIR ($CWD)"
    echo "Branch: $BRANCH"
    [ "$DIRTY" -gt 0 ] && echo "Uncommitted changes: $DIRTY files"

    # Recent commits
    RECENT=$(git -C "$CWD" log --oneline -3 2>/dev/null)
    if [ -n "$RECENT" ]; then
        echo ""
        echo "Recent commits:"
        echo "$RECENT"
    fi

    # Open PRs (requires gh CLI)
    if command -v gh &>/dev/null; then
        OPEN_PRS=$(gh pr list --state open --limit 5 --json number,title \
            --template '{{range .}}  #{{.number}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null)
        if [ -n "$OPEN_PRS" ]; then
            echo ""
            echo "Open PRs:"
            echo "$OPEN_PRS"
        fi
    fi
fi

exit 0
