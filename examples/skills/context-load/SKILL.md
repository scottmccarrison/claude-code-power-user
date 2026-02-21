---
name: context-load
description: >
  Load project-specific context and instructions. Invoke with /context-load
  followed by a project name. Available contexts are defined in references/.
---

# Context Loader

Load the context matching: **$ARGUMENTS**

## Available Contexts

| Context | Reference |
|---------|-----------|
| meal-planning | `references/meal-planning.md` |
| mcdev | `references/mcdev.md` |
| therapy | `references/therapy.md` |

## Instructions

1. Match `$ARGUMENTS` to a context name (case-insensitive)
2. Read the corresponding reference file
3. Internalize those instructions for this conversation
4. Confirm with a brief summary of what was loaded
5. If no match, list available contexts
