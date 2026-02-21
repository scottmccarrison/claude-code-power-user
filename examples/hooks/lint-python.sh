#!/bin/bash
# PostToolUse hook: auto-lint Python files after Edit/Write
# Matcher: Edit|Write
#
# Catches syntax errors immediately after Claude edits a .py file.
# Uses py_compile (stdlib) — no extra dependencies needed.

INPUT=$(cat)
FILE_PATH=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" <<< "$INPUT" 2>/dev/null)

if [[ "$FILE_PATH" == *.py ]] && [[ -f "$FILE_PATH" ]]; then
    PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")
    if ! "$PYTHON" -m py_compile "$FILE_PATH" 2>&1; then
        echo "Syntax error in $FILE_PATH" >&2
    fi
fi

exit 0
