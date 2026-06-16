#!/usr/bin/env bash
# gate25-session-start.sh — SessionStart hook
#
# Records Java file baseline at session start and clears old markers.
# This enables the Stop hook to detect which Java files were changed
# during THIS session (vs pre-existing uncommitted changes).

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MARKER_DIR="$PROJECT_DIR/.gate25-markers"
TMP_DIR="$PROJECT_DIR/.claude/tmp"
BASELINE_FILE="$TMP_DIR/gate25-baseline.txt"

# Ensure tmp directory exists
mkdir -p "$TMP_DIR"

# Record current Java file state as baseline
cd "$PROJECT_DIR"
git status --porcelain -u 2>/dev/null | grep '\.java$' | sort > "$BASELINE_FILE" || true

# Clear old markers from previous sessions
if [[ -d "$MARKER_DIR" ]]; then
  rm -f "$MARKER_DIR"/*.marker.json 2>/dev/null || true
fi

exit 0
