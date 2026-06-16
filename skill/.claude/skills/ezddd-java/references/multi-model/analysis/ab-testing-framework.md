# A/B Testing Framework: Ensemble vs Single-Model

## Purpose

Provide a rigorous method to quantify the value of multi-model ensemble review
compared to single-model (Claude-only) review.

## Experimental Design

### Arms

| Arm | Configuration | Description |
|-----|--------------|-------------|
| **A** (Baseline) | Claude Opus/Sonnet only | Best single model, used as reference |
| **B** (Treatment) | 4-model ensemble | Claude + Gemini + ChatGPT + Codex |

### Ground Truth

Ground truth is established by:
1. **Expert manual review** — when available (e.g., instructor review of student code)
2. **Known bugs** — pre-existing bugs intentionally left in test code
3. **Post-hoc validation** — checking flagged issues against actual code behavior

## Metrics

| Metric | Formula | Description |
|--------|---------|-------------|
| Precision | TP / (TP + FP) | % of flagged issues that are real |
| Recall | TP / (TP + FN) | % of real issues that were found |
| F1 | 2 * P * R / (P + R) | Harmonic mean of precision and recall |
| **EVS** | confirmed_by_multi_only / total_confirmed | **Ensemble Value Score** — issues found only by ensemble |

### EVS Interpretation

| EVS | Meaning |
|-----|---------|
| 0.0 | Single model catches everything — ensemble adds no value |
| 0.1–0.2 | Ensemble provides marginal improvement |
| 0.3–0.5 | Ensemble provides significant added coverage |
| > 0.5 | Single model misses majority of issues — ensemble is essential |

## Shadow Mode Protocol

During every multi-model review, Claude-only results are automatically
preserved as a baseline for comparison, requiring **zero additional cost or effort**.

### How It Works

1. **Phase 2 dispatch** (see `dispatch.md`):
   - Claude sub-agent results are saved as `{review_dir}/claude-raw.json` (already standard)
   - Additionally, copy Claude's findings to `{review_dir}/baseline-claude.json`

2. **Phase 5 comparison**:
   - Parse `baseline-claude.json` findings (Arm A)
   - Parse `aggregated-report.json` consensus findings (Arm B)
   - Compute: which confirmed findings are **absent** from Claude-only baseline?
   - These are the "ensemble-only catches"

3. **Metrics emission**:
   - Compute EVS = ensemble_only_catches / total_confirmed
   - Append to `metrics-history.jsonl`:
     ```json
     { "ab_testing": { "evs": 0.125, "claude_only_findings": 7, "ensemble_findings": 8, "ensemble_only": 1 } }
     ```

### Implementation Steps (for dispatch.md Phase 5)

```bash
# Step 5.4: Shadow Mode Comparison
# 1. Read Claude-only findings
CLAUDE_FINDINGS=$(jq '[.findings[].id]' $REVIEW_DIR/baseline-claude.json)

# 2. Read consensus confirmed findings
CONSENSUS_FINDINGS=$(jq '[.consensus_findings[] | select(.status == "confirmed") | .finding_id]' \
  $REVIEW_DIR/aggregated-report.json)

# 3. Compute EVS
# ensemble_only = findings in CONSENSUS_FINDINGS but not in CLAUDE_FINDINGS
# EVS = ensemble_only_count / total_confirmed_count
```

## Existing Evidence (N=3)

### Session: create-stage-20251230-183739

- **Problem**: Only ChatGPT responded (Gemini/Grok failed) → effectively single-model
- **Arbitration**: Claude rejected ChatGPT's finding (CF-001: false positive about boardId)
- **EVS**: N/A (degraded mode, only 1 external model)
- **Lesson**: Single model without cross-validation produces false positives

### Session: create-stage-20251230-192442

- **Models**: 5 (ChatGPT, Gemini, Codex, Qwen14B, Qwen32B)
- **Claude arbitration**: 20 raw → 12 unique → 5 confirmed, 7 rejected
- **EVS**: ~0.0 (all confirmed findings were also seen by multiple models)
- **Lesson**: Ensemble's primary value was **noise filtering** (58% rejection rate)

### Session: ezscrum-all-frames-20260105-210107

- **Models**: 5 (Claude, Gemini, ChatGPT, Codex, Qwen)
- **Claude-only findings**: 7 out of 8 unique findings
- **Ensemble-only catches**: 1 (AGG-008, found only by Codex)
- **EVS**: 1/8 = **0.125** (based on unique findings) or 0/2 = **0.0** (based on confirmed-only)
- **Lesson**: Codex provides unique code-specialized coverage that Claude misses

### Preliminary Summary (N=3)

| Metric | Value |
|--------|-------|
| Average EVS (unique-based) | ~0.04 |
| Sessions where ensemble found extra issues | 1/3 (33%) |
| Primary ensemble benefit | Noise filtering (58-78% rejection) |
| Secondary ensemble benefit | Unique coverage from specialized models |

## Statistical Requirements

| Requirement | Current | Target |
|------------|---------|--------|
| Paired samples (N) | 3 | ≥ 10 |
| Statistical test | — | Paired t-test or Wilcoxon signed-rank |
| Significance level | — | α = 0.05 |
| Estimated reviews to target | — | ~7 more reviews |

**Status**: Framework is in place, data accumulates automatically via Shadow Mode.
After N=10, a formal statistical comparison can determine if ensemble review
provides a statistically significant improvement over Claude-only review.

## Decision Criteria

After reaching N≥10, the following decision matrix applies:

| EVS Range | Noise Reduction | Decision |
|-----------|-----------------|----------|
| EVS > 0.3 | Any | Keep ensemble — significant unique coverage |
| EVS 0.1–0.3 | > 50% | Keep ensemble — noise filtering justifies cost |
| EVS < 0.1 | > 50% | Keep ensemble — noise filtering alone is valuable |
| EVS < 0.1 | < 30% | Consider reducing to 2-model (Claude + best secondary) |
