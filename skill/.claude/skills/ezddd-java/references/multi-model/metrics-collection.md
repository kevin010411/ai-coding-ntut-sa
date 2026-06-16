# Metrics Collection Protocol

Defines mandatory metrics collected after every multi-model review (dispatch.md Phase 5).

## Mandatory Metrics

After Phase 5 (report generation), the following metrics MUST be appended to
`.dev/reviews/metrics-history.jsonl`:

```yaml
# Per-review metrics record
session_id: "ezscrum-all-frames-20260105-210107"   # matches review_id

timing:
  wall_clock_s: 289
  per_model:
    claude: 45
    gemini: 66
    chatgpt: 10.7
    codex: 289
  speedup_factor: 1.75          # sequential_total / wall_clock

quality:
  raw_findings: 37              # total findings across all models (before dedup)
  unique_after_dedup: 8         # after normalization and grouping
  confirmed: 2                  # consensus_score >= 0.75
  likely: 4                     # 0.50 <= consensus_score < 0.75
  disputed: 0                   # 0.30 <= consensus_score < 0.50
  unique: 2                     # consensus_score < 0.30
  false_positives_rejected: 0   # rejected by arbitration

cost:
  chatgpt_usd: 0.02
  codex_usd: 0.03
  total_external_usd: 0.05

model_contribution:
  claude:  { findings: 12, unique_catches: 0 }
  gemini:  { findings: 10, unique_catches: 0 }
  chatgpt: { findings: 5,  unique_catches: 0 }
  codex:   { findings: 5,  unique_catches: 1 }
```

## JSONL Storage Format

Each review appends one JSON line to `.dev/reviews/metrics-history.jsonl`:

```json
{"session_id":"create-stage-20251230-192442","timestamp":"2025-12-30T19:24:42+08:00","timing":{"wall_clock_s":120,"speedup_factor":1.0},"quality":{"raw_findings":20,"unique_after_dedup":12,"confirmed":5,"likely":0,"disputed":0,"unique":7,"false_positives_rejected":7},"cost":{"total_external_usd":0.05},"models_responded":5}
{"session_id":"ezscrum-all-frames-20260105-210107","timestamp":"2026-01-05T21:01:07+08:00","timing":{"wall_clock_s":289,"speedup_factor":1.75},"quality":{"raw_findings":37,"unique_after_dedup":8,"confirmed":2,"likely":4,"disputed":0,"unique":2,"false_positives_rejected":0},"cost":{"total_external_usd":0.05},"models_responded":5}
```

## Collection Trigger

Metrics are collected in **dispatch.md Phase 5, Step 5.2** (before moving to completed):

```
Step 5.2a: Collect metrics from timing.json + aggregated-report.json
Step 5.2b: Append JSONL line to .dev/reviews/metrics-history.jsonl
Step 5.2c: Move to completed directory
```

## Analysis Queries

Common `jq` queries for metrics analysis:

```bash
# Average parallel speedup
jq -s '[.[].timing.speedup_factor] | add / length' .dev/reviews/metrics-history.jsonl

# Average dedup ratio (unique / raw)
jq -s '[.[] | .quality.unique_after_dedup / .quality.raw_findings] | add / length' \
  .dev/reviews/metrics-history.jsonl

# Total cost across all reviews
jq -s '[.[].cost.total_external_usd] | add' .dev/reviews/metrics-history.jsonl

# Cost per confirmed finding
jq -s '[.[] | select(.quality.confirmed > 0) | .cost.total_external_usd / .quality.confirmed] | add / length' \
  .dev/reviews/metrics-history.jsonl

# Model with most unique catches (requires per-model data)
# Use analyze-multi-model-metrics.sh for detailed analysis
```

## Backfill

For reviews completed before metrics collection was introduced, run:

```bash
bash .claude/skills/ezddd-java/scripts/analyze-multi-model-metrics.sh --backfill
```

This scans `.dev/reviews/completed/*/` and generates `metrics-history.jsonl` from
existing `timing.json` and `aggregated-report.json` files.
