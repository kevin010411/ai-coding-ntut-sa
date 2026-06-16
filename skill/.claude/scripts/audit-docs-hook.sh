#!/bin/bash
# Post-Edit Hook: Audit CLAUDE.md references when docs are modified
# Only runs when CLAUDE.md or SKILL.md files are edited

FILE_PATH="${CLAUDE_FILE_PATH:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Only trigger for CLAUDE.md or SKILL.md changes
case "$FILE_PATH" in
  *CLAUDE.md|*SKILL.md) ;;
  *) exit 0 ;;
esac

python3 "$PROJECT_DIR/.claude/scripts/audit-docs.py" --hook
