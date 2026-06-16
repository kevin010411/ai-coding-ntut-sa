# Weighted Consensus Aggregator

## Purpose

Aggregates findings from multiple LLM reviewers using a weighted consensus algorithm.
This enables combining the strengths of different models while filtering out false positives.

## Algorithm Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AGGREGATION PIPELINE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Step 1: Collect Results                                        │
│  ───────────────────────                                        │
│  • Read all model results from .dev/reviews/in-progress/{id}/   │
│  • Parse JSON according to review-result.schema.json            │
│                                                                 │
│  Step 2: Normalize Finding IDs                                  │
│  ─────────────────────────────                                  │
│  • Create canonical ID from: category + spec_reference          │
│  • Example: "missing-attribute:aggregate.yaml:175" → "MA-AGG-175"│
│  • Group findings by normalized ID                              │
│                                                                 │
│  Step 3: Calculate Consensus Scores                             │
│  ──────────────────────────────────                             │
│  • For each unique finding:                                     │
│    - models_agreed = count of models reporting this finding     │
│    - total_models = total participating models                  │
│    - avg_confidence = mean of confidence scores                 │
│    - consensus_score = (models_agreed / total_models) * avg_conf│
│                                                                 │
│  Step 4: Classify Findings                                      │
│  ─────────────────────────                                      │
│  • confirmed:    consensus_score >= 0.75                        │
│  • likely:       0.50 <= consensus_score < 0.75                 │
│  • disputed:     0.30 <= consensus_score < 0.50                 │
│  • unique:       consensus_score < 0.30 (single model only)     │
│                                                                 │
│  Step 5: Determine Severity                                     │
│  ──────────────────────────                                     │
│  • Use highest severity reported by any agreeing model          │
│  • Boost severity if all models agree                           │
│                                                                 │
│  Step 6: Arbitrate Disputed Findings                            │
│  ───────────────────────────────────                            │
│  • Claude reviews disputed findings                             │
│  • Reads actual code to make final determination                │
│  • Marks as confirmed, rejected, or modified                    │
│                                                                 │
│  Step 7: Generate Final Report                                  │
│  ─────────────────────────────                                  │
│  • Merge confirmed + arbitrated findings                        │
│  • Calculate final compliance rate                              │
│  • Determine final verdict                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Consensus Thresholds

| Consensus Score | Status | Model Agreement | Action |
|-----------------|--------|-----------------|--------|
| >= 0.75 | **Confirmed** | 3/4 or 4/4 models | Must fix |
| 0.50 - 0.74 | **Likely** | 2/4 models with high confidence | Should fix |
| 0.30 - 0.49 | **Disputed** | 1/4 models, low confidence | Claude arbitrates |
| < 0.30 | **Unique** | 1/4 model only | Log for reference |

## Finding Normalization Rules

### Category-Based ID Generation

```
Normalized ID = {CATEGORY_CODE}-{FILE_CODE}-{LINE}

Category Codes:
  missing-attribute      → MA
  type-mismatch          → TM
  missing-precondition   → MP
  missing-postcondition  → MO
  missing-invariant      → MI
  missing-test           → MT
  missing-assertion      → AS
  logic-error            → LE
  naming-mismatch        → NM
  contract-violation     → CV
  event-schema-mismatch  → ES
  other                  → OT

File Codes:
  aggregate.yaml         → AGG
  use-case.yaml          → UC
  machine.yaml           → MCH
  *.java                 → {ClassName}
```

### Example Normalization

```
Model A Finding:
{
  "id": "F001",
  "category": "missing-attribute",
  "spec_reference": "aggregate.yaml:175",
  "description": "boardId missing from StageCreated event"
}

Model B Finding:
{
  "id": "F003",
  "category": "missing-attribute",
  "spec_reference": "aggregate.yaml:175-177",
  "description": "StageCreated event lacks boardId field"
}

→ Both normalize to: MA-AGG-175
→ Grouped together, consensus_score = 2/4 models * avg_confidence
```

## Model Weights

Default weights adjusted for current 4-model lineup:

```json
{
  "claude": 1.5,    // Arbitrator bonus, highest reasoning capability
  "gemini": 1.0,    // Strong general-purpose
  "chatgpt": 1.2,   // Strong code analysis (gpt-5.2)
  "codex": 1.2      // Code-specialized (gpt-5-codex)
}
```

## Weight Rationale

Weights reflect each model's **contribution quality** observed in historical reviews
(3 sessions: create-stage 2025-12-30, create-stage-5model 2025-12-30, ezscrum-all-frames 2026-01-05):

| Model | Weight | Justification |
|-------|--------|---------------|
| Claude | 1.5 | Arbitrator role; highest finding count (12); 0.88 compliance rate |
| ChatGPT | 1.2 | Strong code analysis; 0.85 compliance rate; fastest response (10.7s) |
| Codex | 1.2 | Code-specialized; found unique issues (e.g., AGG-008 boardId validation) |
| Gemini | 1.0 | Baseline weight; strictest grading (0.45 compliance rate); large context window |

### Calibration Policy

Weights are reviewed after every **10 multi-model reviews** (or quarterly, whichever comes first).

**Adjustment triggers**:
- If a model's precision drops below **0.7**: reduce weight by 0.2, flag for investigation
- If a model's recall drops below **0.3**: reduce weight by 0.2, flag for investigation
- If a model consistently finds **unique confirmed issues**: increase weight by 0.1

**Historical calibration log**:
| Date | Change | Reason |
|------|--------|--------|
| 2025-12-30 | Qwen removed (was 0.8) | F1=0.57, low recall, 94~120s latency |
| 2026-01-05 | Codex → 1.2 (was 1.0) | Found unique AGG-008 issue |

## Weighted Consensus Formula

When all models respond:
```
weighted_consensus = Σ(model_weight * model_confidence) / Σ(all_model_weights)
```

When some models fail or timeout (**graceful degradation**):
```
weighted_consensus = Σ(responding_weight * confidence) / Σ(responding_weights)
```

**Important**: The denominator uses only **responding** model weights, not all 4.
This prevents failed models from diluting consensus scores.

## Minimum Model Threshold

| Responding Models | Mode | Behavior |
|-------------------|------|----------|
| 4 | **Normal** | Full consensus algorithm |
| 3 | **Partial** | Weighted consensus with warning; note missing models in report |
| 2 | **Degraded** | Claude arbitrates ALL findings (no consensus voting) |
| 1 | **Single-Model** | Report as single-model review, no consensus possible |
| 0 | **Failure** | Abort with error; no report generated |

## Verdict Determination

```
Final Verdict Logic:

IF any confirmed finding has severity == "critical":
    verdict = "fail"
ELSE IF confirmed_count >= 3 AND all are "low":
    verdict = "pass"
ELSE IF weighted_compliance_rate >= 0.95:
    verdict = "pass"
ELSE IF weighted_compliance_rate < 0.80:
    verdict = "fail"
ELSE:
    verdict = "needs-review"
```

## Output Format

See `aggregated-report.schema.json` for the full output schema.

## Usage in Claude Code

```
User: "聚合這些模型的審查結果"

Claude:
1. 讀取 .dev/reviews/in-progress/{id}/*.json
2. 解析各模型結果
3. 執行 normalize_findings()
4. 執行 calculate_consensus()
5. 對 disputed findings 進行仲裁
6. 產生 aggregated-report.json
7. 產生 final-report.md (人類可讀格式)
```
