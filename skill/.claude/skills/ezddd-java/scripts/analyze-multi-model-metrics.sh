#!/usr/bin/env bash
# analyze-multi-model-metrics.sh — Analyze multi-model review metrics
#
# Scans .dev/reviews/completed/*/aggregated-report.json and timing.json
# to produce summary statistics on cost, speedup, dedup, and model contribution.
#
# Usage:
#   bash .claude/skills/ezddd-java/scripts/analyze-multi-model-metrics.sh [--roi] [--backfill]
#
# Options:
#   --roi       Include cost-per-critical-issue calculation
#   --backfill  Generate metrics-history.jsonl from existing review data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REVIEWS_DIR="$PROJECT_ROOT/.dev/reviews/completed"
METRICS_FILE="$PROJECT_ROOT/.dev/reviews/metrics-history.jsonl"

SHOW_ROI=false
DO_BACKFILL=false

for arg in "$@"; do
  case "$arg" in
    --roi) SHOW_ROI=true ;;
    --backfill) DO_BACKFILL=true ;;
  esac
done

if [[ ! -d "$REVIEWS_DIR" ]]; then
  echo "ERROR: Reviews directory not found: $REVIEWS_DIR"
  exit 1
fi

# Count review sessions
SESSION_DIRS=()
while IFS= read -r dir; do
  if [[ -f "$dir/aggregated-report.json" ]]; then
    SESSION_DIRS+=("$dir")
  fi
done < <(find "$REVIEWS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

TOTAL_SESSIONS=${#SESSION_DIRS[@]}

if [[ $TOTAL_SESSIONS -eq 0 ]]; then
  echo "No completed reviews found with aggregated-report.json"
  exit 0
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          MULTI-MODEL REVIEW METRICS ANALYSIS                  ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Reviews analyzed: $TOTAL_SESSIONS                                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# --- Timing Analysis ---
echo "## Timing Analysis"
echo ""

TOTAL_WALL=0
TOTAL_SEQUENTIAL=0
SESSIONS_WITH_TIMING=0

for dir in "${SESSION_DIRS[@]}"; do
  if [[ -f "$dir/timing.json" ]]; then
    WALL=$(jq -r '.wall_clock_seconds // 0' "$dir/timing.json")
    SEQ=$(jq -r '.sequential_total_ms // 0' "$dir/timing.json")
    SESSION_NAME=$(basename "$dir")

    if [[ "$SEQ" -gt 0 ]]; then
      SEQ_S=$((SEQ / 1000))
      SPEEDUP=$(echo "scale=2; $SEQ_S / $WALL" | bc 2>/dev/null || echo "N/A")
      echo "  $SESSION_NAME: wall=${WALL}s, sequential=${SEQ_S}s, speedup=${SPEEDUP}x"
    else
      echo "  $SESSION_NAME: wall=${WALL}s"
    fi

    TOTAL_WALL=$((TOTAL_WALL + WALL))
    TOTAL_SEQUENTIAL=$((TOTAL_SEQUENTIAL + SEQ / 1000))
    SESSIONS_WITH_TIMING=$((SESSIONS_WITH_TIMING + 1))
  fi
done

if [[ $SESSIONS_WITH_TIMING -gt 0 ]]; then
  AVG_WALL=$((TOTAL_WALL / SESSIONS_WITH_TIMING))
  echo ""
  echo "  Average wall clock: ${AVG_WALL}s"
  if [[ $TOTAL_SEQUENTIAL -gt 0 ]]; then
    AVG_SPEEDUP=$(echo "scale=2; $TOTAL_SEQUENTIAL / $TOTAL_WALL" | bc 2>/dev/null || echo "N/A")
    echo "  Average speedup: ${AVG_SPEEDUP}x"
  fi
fi

echo ""

# --- Quality Analysis ---
echo "## Quality Analysis (Dedup & Confirmation)"
echo ""

TOTAL_RAW=0
TOTAL_UNIQUE=0
TOTAL_CONFIRMED=0

for dir in "${SESSION_DIRS[@]}"; do
  SESSION_NAME=$(basename "$dir")
  REPORT="$dir/aggregated-report.json"

  RAW=$(jq -r '.summary.total_raw_findings // .arbitration.total_findings_before_dedup // (.consensus_findings | length) // 0' "$REPORT")
  UNIQUE=$(jq -r '.summary.total_unique_findings // .summary.unique_aggregated_findings // .arbitration.unique_findings // (.consensus_findings | length) // 0' "$REPORT")
  CONFIRMED=$(jq -r '.summary.confirmed_findings // .summary.by_consensus.confirmed // .summary.after_arbitration.confirmed_high // ([.consensus_findings[]? | select(.status == "confirmed" or .arbitration.decision == "confirmed")] | length) // 0' "$REPORT")

  if [[ "$RAW" -gt 0 ]]; then
    DEDUP_RATIO=$(echo "scale=1; $UNIQUE * 100 / $RAW" | bc 2>/dev/null || echo "N/A")
    echo "  $SESSION_NAME: raw=$RAW → unique=$UNIQUE (${DEDUP_RATIO}%), confirmed=$CONFIRMED"
  else
    echo "  $SESSION_NAME: raw=$RAW, unique=$UNIQUE, confirmed=$CONFIRMED"
  fi

  TOTAL_RAW=$((TOTAL_RAW + RAW))
  TOTAL_UNIQUE=$((TOTAL_UNIQUE + UNIQUE))
  TOTAL_CONFIRMED=$((TOTAL_CONFIRMED + CONFIRMED))
done

echo ""
if [[ $TOTAL_RAW -gt 0 ]]; then
  AVG_DEDUP=$(echo "scale=1; $TOTAL_UNIQUE * 100 / $TOTAL_RAW" | bc 2>/dev/null || echo "N/A")
  NOISE_REDUCTION=$(echo "scale=1; 100 - $AVG_DEDUP" | bc 2>/dev/null || echo "N/A")
  echo "  Totals: raw=$TOTAL_RAW, unique=$TOTAL_UNIQUE, confirmed=$TOTAL_CONFIRMED"
  echo "  Average dedup ratio: ${AVG_DEDUP}%"
  echo "  Noise reduction: ${NOISE_REDUCTION}%"
fi

echo ""

# --- Model Contribution ---
echo "## Model Contribution Ranking"
echo ""

for dir in "${SESSION_DIRS[@]}"; do
  SESSION_NAME=$(basename "$dir")
  REPORT="$dir/aggregated-report.json"

  STATS=$(jq -r '.model_stats // empty' "$REPORT" 2>/dev/null)
  if [[ -n "$STATS" ]]; then
    echo "  $SESSION_NAME:"
    echo "$STATS" | jq -r 'to_entries | sort_by(-.value.findings) | .[] | "    \(.key): \(.value.findings) findings, compliance=\(.value.compliance_rate)"'
    echo ""
  fi
done

# --- ROI Analysis ---
if [[ "$SHOW_ROI" == "true" ]]; then
  echo "## ROI Analysis"
  echo ""

  COST_PER_REVIEW=0.05
  TOTAL_COST=$(echo "scale=2; $TOTAL_SESSIONS * $COST_PER_REVIEW" | bc 2>/dev/null || echo "N/A")

  echo "  External cost per review: \$${COST_PER_REVIEW}"
  echo "  Total cost ($TOTAL_SESSIONS reviews): \$${TOTAL_COST}"

  if [[ $TOTAL_CONFIRMED -gt 0 ]]; then
    COST_PER_FINDING=$(echo "scale=3; $TOTAL_COST / $TOTAL_CONFIRMED" | bc 2>/dev/null || echo "N/A")
    echo "  Cost per confirmed finding: \$${COST_PER_FINDING}"
  fi

  echo ""
  echo "  Comparison: Manual code review typically costs \$50-150/hour."
  echo "  At \$0.05/review, multi-model review is ~1000x cheaper than manual review."
fi

# --- Backfill ---
if [[ "$DO_BACKFILL" == "true" ]]; then
  echo ""
  echo "## Backfilling metrics-history.jsonl"
  echo ""

  > "$METRICS_FILE"  # truncate

  for dir in "${SESSION_DIRS[@]}"; do
    SESSION_NAME=$(basename "$dir")
    REPORT="$dir/aggregated-report.json"

    TIMESTAMP=$(jq -r '.reviewed_at // .timestamp // "unknown"' "$REPORT")
    RAW=$(jq -r '.summary.total_raw_findings // .arbitration.total_findings_before_dedup // (.consensus_findings | length) // 0' "$REPORT")
    UNIQUE=$(jq -r '.summary.total_unique_findings // .summary.unique_aggregated_findings // .arbitration.unique_findings // (.consensus_findings | length) // 0' "$REPORT")
    CONFIRMED=$(jq -r '.summary.confirmed_findings // .summary.by_consensus.confirmed // .summary.after_arbitration.confirmed_high // ([.consensus_findings[]? | select(.status == "confirmed" or .arbitration.decision == "confirmed")] | length) // 0' "$REPORT")
    MODELS=$(jq -r '(.models_participated | length) // (.models_called | keys | length) // 0' "$REPORT" 2>/dev/null || echo 0)

    WALL=0
    SPEEDUP=1.0
    if [[ -f "$dir/timing.json" ]]; then
      WALL=$(jq -r '.wall_clock_seconds // 0' "$dir/timing.json")
      SPEEDUP=$(jq -r '.parallel_speedup // "1.0"' "$dir/timing.json" | tr -d 'x')
    fi

    jq -cn \
      --arg sid "$SESSION_NAME" \
      --arg ts "$TIMESTAMP" \
      --argjson wall "$WALL" \
      --arg speedup "$SPEEDUP" \
      --argjson raw "$RAW" \
      --argjson unique "$UNIQUE" \
      --argjson confirmed "$CONFIRMED" \
      --argjson models "$MODELS" \
      '{
        session_id: $sid,
        timestamp: $ts,
        timing: { wall_clock_s: $wall, speedup_factor: ($speedup | tonumber) },
        quality: { raw_findings: $raw, unique_after_dedup: $unique, confirmed: $confirmed },
        cost: { total_external_usd: 0.05 },
        models_responded: $models
      }' >> "$METRICS_FILE"

    echo "  Backfilled: $SESSION_NAME"
  done

  echo ""
  echo "  Written to: $METRICS_FILE"
  echo "  Lines: $(wc -l < "$METRICS_FILE" | tr -d ' ')"
fi

echo ""
echo "Done."
