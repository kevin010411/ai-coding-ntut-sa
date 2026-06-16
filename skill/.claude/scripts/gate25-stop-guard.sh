#!/usr/bin/env bash
# gate25-stop-guard.sh — Stop hook (deterministic gate)
#
# Prevents session from ending if Java files were changed but
# Gate 2.5 was not executed (no marker) or code was modified after validation
# (checksum mismatch).
#
# Exit codes:
#   0 = allow stop (no Java changes, or marker valid)
#   2 = block stop (missing marker or checksum mismatch)

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MARKER_DIR="$PROJECT_DIR/.gate25-markers"
BASELINE_FILE="$PROJECT_DIR/.claude/tmp/gate25-baseline.txt"

# ─────────────────────────────────────────────────────────────
# Step 1: Compute Java file diff (this session only)
# ─────────────────────────────────────────────────────────────

cd "$PROJECT_DIR"

current_state=$(git status --porcelain -u 2>/dev/null | grep '\.java$' | sort || true)

if [[ -f "$BASELINE_FILE" ]]; then
  baseline_state=$(cat "$BASELINE_FILE")
else
  # No baseline file = SessionStart hook didn't run; treat all as this session's
  baseline_state=""
fi

# No Java files with changes at all
if [[ -z "$current_state" ]]; then
  exit 0
fi

# No new Java changes since session start
if [[ "$current_state" == "$baseline_state" ]]; then
  exit 0
fi

# Extract just the file paths from porcelain output (column 2+)
session_java_files=$(diff <(echo "$baseline_state") <(echo "$current_state") 2>/dev/null \
  | grep '^>' | sed 's/^> //' | awk '{print $NF}' | sort || true)

if [[ -z "$session_java_files" ]]; then
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Step 2: Check markers exist
# ─────────────────────────────────────────────────────────────

if [[ ! -d "$MARKER_DIR" ]] || [[ -z "$(ls -A "$MARKER_DIR" 2>/dev/null)" ]]; then
  java_count=$(echo "$session_java_files" | wc -l | tr -d ' ')
  cat <<EOF >&2
{
  "decision": "block",
  "reason": "Gate 2.5 not executed. ${java_count} Java file(s) changed in this session but no validation marker found. Run validate-generated-code.sh before completing."
}
EOF
  exit 2
fi

# ─────────────────────────────────────────────────────────────
# Step 3: Verify checksums for each marker
# ─────────────────────────────────────────────────────────────

compute_checksum() {
  local files_pattern="$1"
  local checksum=""

  if [[ -d "$PROJECT_DIR/src" ]]; then
    checksum=$(find "$PROJECT_DIR/src" -path "*/${files_pattern}/*.java" -type f 2>/dev/null \
      | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
  fi

  echo "${checksum:-empty}"
}

all_valid=true
block_reasons=""

for marker_file in "$MARKER_DIR"/*.marker.json; do
  [[ ! -f "$marker_file" ]] && continue

  # Parse marker (portable JSON parsing without jq dependency)
  marker_aggregate=$(grep -o '"aggregate": *"[^"]*"' "$marker_file" | cut -d'"' -f4)
  marker_checksum=$(grep -o '"files_checksum": *"[^"]*"' "$marker_file" | cut -d'"' -f4)

  if [[ -z "$marker_aggregate" || -z "$marker_checksum" ]]; then
    all_valid=false
    block_reasons="${block_reasons}Invalid marker file: $(basename "$marker_file"). "
    continue
  fi

  # Recompute checksum
  agg_lower=$(echo "$marker_aggregate" | tr '[:upper:]' '[:lower:]')
  current_checksum=$(compute_checksum "$agg_lower")

  if [[ "$current_checksum" != "$marker_checksum" ]]; then
    all_valid=false
    block_reasons="${block_reasons}Checksum mismatch for aggregate '${marker_aggregate}': code was modified after Gate 2.5 validation. Re-run validate-generated-code.sh --aggregate ${marker_aggregate}. "
  fi
done

if [[ "$all_valid" == "true" ]]; then
  exit 0
fi

cat <<EOF >&2
{
  "decision": "block",
  "reason": "${block_reasons}"
}
EOF
exit 2
