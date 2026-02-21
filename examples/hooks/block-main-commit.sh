#!/bin/bash
# PreToolUse hook: block git commits directly to main/master
# Matcher: Bash
#
# Reads JSON from stdin, extracts the bash command, and blocks
# if it's a git commit on the main or master branch.
#
# Exit 0 = allow, Exit 2 = block

INPUT=$(cat)
COMMAND=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" <<< "$INPUT" 2>/dev/null)

# Only check git commit commands
if echo "$COMMAND" | grep -q 'git commit'; then
    # Determine the target repo directory from the command
    REPO_DIR=""

    # Check for "cd /path && git commit"
    if [[ "$COMMAND" =~ cd[[:space:]]+([^&\;]+) ]]; then
        REPO_DIR="${BASH_REMATCH[1]}"
        REPO_DIR="${REPO_DIR%% }"
        REPO_DIR=$(eval echo "$REPO_DIR" 2>/dev/null)
    fi

    # Check for "git -C /path commit"
    if [[ "$COMMAND" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
        REPO_DIR="${BASH_REMATCH[1]}"
        REPO_DIR=$(eval echo "$REPO_DIR" 2>/dev/null)
    fi

    # Exempt specific repos (e.g., docs repo is always direct-to-main)
    RESOLVED_DIR=$(cd "${REPO_DIR:-.}" 2>/dev/null && pwd)
    if [[ "$RESOLVED_DIR" == */docs ]]; then
        exit 0
    fi

    # Check the branch in the target repo
    BRANCH=$(git -C "${REPO_DIR:-.}" branch --show-current 2>/dev/null)
    if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
        echo "Blocked: committing directly to $BRANCH. Use a feature branch." >&2
        exit 2
    fi
fi

exit 0
