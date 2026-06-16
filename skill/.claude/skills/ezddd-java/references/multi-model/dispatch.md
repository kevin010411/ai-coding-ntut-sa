# Multi-Model Dispatch Engine

共用的 4-LLM 平行 dispatch 引擎。被 `code-reviewer/workflow.md` (--multi) 引用。

## Input Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{PROMPT_FILE}` | prompt 檔案路徑（已寫入 disk） | `/tmp/review_prompt.txt` |
| `{REVIEW_DIR}` | 輸出目錄 | `.dev/reviews/code-review/{id}` |
| `{REVIEW_TYPE}` | `spec-compliance` 或 `code-quality` | 決定使用哪個 prompt 模板 |

## Prompt Strategy Selection

| REVIEW_TYPE | Prompt Template | Use Case |
|-------------|----------------|----------|
| `spec-compliance` | `multi-model/prompts/spec-compliance-review.md` | Spec compliance review |
| `code-quality` | `multi-model/prompts/code-quality-review.md` | Code reviewer --multi |

---

## Phase 1: Pre-flight Availability Check

Before dispatching, verify which models are available. This prevents wasted time
waiting for models that will never respond.

```bash
REVIEW_DIR="{REVIEW_DIR}"
MIN_MODELS=3
AVAILABLE_MODELS=()

# Check Gemini CLI
if command -v gemini &>/dev/null; then
  AVAILABLE_MODELS+=("gemini")
  echo "✅ Gemini CLI available"
else
  echo "⚠️ Gemini CLI not found — will skip"
fi

# Check OpenAI API key
if [[ -n "${OPENAI_API_KEY:-}" ]] || (source ~/.zshrc 2>/dev/null && [[ -n "${OPENAI_API_KEY:-}" ]]); then
  AVAILABLE_MODELS+=("chatgpt")
  echo "✅ ChatGPT API key found"
else
  echo "⚠️ OPENAI_API_KEY not set — will skip ChatGPT"
fi

# Check Codex CLI
if command -v codex &>/dev/null; then
  AVAILABLE_MODELS+=("codex")
  echo "✅ Codex CLI available"
else
  echo "⚠️ Codex CLI not found — will skip"
fi

# Claude is always available (sub-agent)
AVAILABLE_MODELS+=("claude")
echo "✅ Claude sub-agent always available"

TOTAL_AVAILABLE=${#AVAILABLE_MODELS[@]}
echo ""
echo "Available models: ${AVAILABLE_MODELS[*]} ($TOTAL_AVAILABLE / 4)"

if [[ $TOTAL_AVAILABLE -lt $MIN_MODELS ]]; then
  echo "❌ ABORT: Only $TOTAL_AVAILABLE models available, minimum is $MIN_MODELS"
  echo "   Install missing tools or lower MIN_MODELS in project-config.json"
  exit 1
fi

if [[ $TOTAL_AVAILABLE -lt 4 ]]; then
  echo "⚠️ WARNING: Running in partial mode ($TOTAL_AVAILABLE / 4 models)"
fi
```

**Decision**: If available models < `MIN_MODELS` (default 3), abort with clear message.

---

## Phase 2: Dispatch to Available Models (Parallel)

**Important**: All 4 models run IN PARALLEL using background processes for maximum speed.

**Output Handling**: Bash tool has 30000 char limit. All LLM output MUST:
1. Write to files (don't rely on stdout)
2. Use **Read tool** to read results (no char limit)
3. Avoid `cat` on large files in bash

### Step 2.0: Initialize & Prepare

```bash
REVIEW_DIR="{REVIEW_DIR}"
PROMPT_FILE="{PROMPT_FILE}"

# Ensure API keys are loaded
source ~/.zshrc

# Prepare ChatGPT request JSON
PROMPT_JSON=$(cat $PROMPT_FILE | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
```

### Step 2.1: Launch All Models in Parallel (with timeouts)

Each model subshell is wrapped with `timeout` to prevent indefinite hangs.
On timeout, an error marker is written to the raw output file.

**Timeout values** (configurable via `project-config.json`):
| Model | Default Timeout | Rationale |
|-------|----------------|-----------|
| Gemini | 180s | Local CLI, may need file processing |
| ChatGPT | 120s | Remote API, network-bound |
| Codex | 180s | Local CLI, full-auto mode |

```bash
PARALLEL_START=$(date +%s)

# Timeout values (seconds)
T_GEMINI=${TIMEOUT_GEMINI:-180}
T_CHATGPT=${TIMEOUT_CHATGPT:-120}
T_CODEX=${TIMEOUT_CODEX:-180}

declare -A MODEL_PIDS

# Model 1: Gemini CLI (background, with timeout)
# Has file access via CLI tools
if [[ " ${AVAILABLE_MODELS[*]} " == *" gemini "* ]]; then
(
  START=$(date +%s%3N)
  if timeout $T_GEMINI bash -c "cat $PROMPT_FILE | gemini -y" > $REVIEW_DIR/gemini-raw.txt 2>&1; then
    END=$(date +%s%3N)
    echo $((END - START)) > $REVIEW_DIR/gemini-latency.txt
    echo "Gemini done: $((END - START))ms"
  else
    echo '{"error": "timeout", "model": "gemini", "timeout_seconds": '"$T_GEMINI"'}' > $REVIEW_DIR/gemini-raw.txt
    echo "Gemini TIMEOUT after ${T_GEMINI}s"
  fi
) &
MODEL_PIDS[gemini]=$!
fi

# Model 2: ChatGPT API (gpt-5.2, with timeout + retry)
# No file access - needs full code in prompt
if [[ " ${AVAILABLE_MODELS[*]} " == *" chatgpt "* ]]; then
(
  START=$(date +%s%3N)
  source ~/.zshrc 2>/dev/null
  PROMPT_CONTENT=$(cat $PROMPT_FILE)
  jq -n --arg content "$PROMPT_CONTENT" '{
    model: "gpt-5.2",
    messages: [{role: "user", content: $content}],
    temperature: 0.1
  }' > /tmp/chatgpt-request.json

  MAX_RETRIES=2
  RETRY=0
  SUCCESS=false

  while [[ $RETRY -le $MAX_RETRIES ]]; do
    HTTP_CODE=$(timeout $T_CHATGPT curl -s -w "%{http_code}" -o $REVIEW_DIR/chatgpt-raw.json \
      https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d @/tmp/chatgpt-request.json 2>&1)

    if [[ "$HTTP_CODE" == "200" ]]; then
      SUCCESS=true
      break
    elif [[ "$HTTP_CODE" == "429" ]] && [[ $RETRY -lt $MAX_RETRIES ]]; then
      echo "ChatGPT 429 rate limited, retry $((RETRY + 1))/$MAX_RETRIES in 30s..."
      sleep 30
      RETRY=$((RETRY + 1))
    else
      break
    fi
  done

  if [[ "$SUCCESS" == "true" ]]; then
    END=$(date +%s%3N)
    echo $((END - START)) > $REVIEW_DIR/chatgpt-latency.txt
    echo "ChatGPT done: $((END - START))ms"
  else
    echo '{"error": "failed", "model": "chatgpt", "http_code": "'"$HTTP_CODE"'"}' > $REVIEW_DIR/chatgpt-raw.json
    echo "ChatGPT FAILED (HTTP $HTTP_CODE)"
  fi
) &
MODEL_PIDS[chatgpt]=$!
fi

# Model 3: Codex CLI (background, with timeout)
# Has file access, uses gpt-5-codex
if [[ " ${AVAILABLE_MODELS[*]} " == *" codex "* ]]; then
(
  START=$(date +%s%3N)
  if timeout $T_CODEX bash -c "cat $PROMPT_FILE | codex exec --full-auto -" > $REVIEW_DIR/codex-raw.txt 2>&1; then
    END=$(date +%s%3N)
    echo $((END - START)) > $REVIEW_DIR/codex-latency.txt
    echo "Codex done: $((END - START))ms"
  else
    echo '{"error": "timeout", "model": "codex", "timeout_seconds": '"$T_CODEX"'}' > $REVIEW_DIR/codex-raw.txt
    echo "Codex TIMEOUT after ${T_CODEX}s"
  fi
) &
MODEL_PIDS[codex]=$!
fi

# Model 4: Claude Sub-agent - see Step 2.1.5 below (uses Task tool, not bash)
echo "Launched ${#MODEL_PIDS[@]} bash models + Claude sub-agent in parallel"
for m in "${!MODEL_PIDS[@]}"; do
  echo "  $m: PID=${MODEL_PIDS[$m]}"
done
```

### Step 2.1.5: Launch Claude Sub-agent in Parallel

Use Task tool with `run_in_background: true` simultaneously with bash dispatch:

```javascript
Task({
  description: "Claude review",
  subagent_type: "general-purpose",
  model: "sonnet",    // Sonnet for cost efficiency; Opus handles arbitration in main
  run_in_background: true,
  prompt: `{prompt content varies by REVIEW_TYPE — see prompt strategy selection above}`
})
```

**Timeout handling**: When collecting Claude results, use `TaskOutput` with explicit timeout:

```javascript
TaskOutput({
  task_id: claude_task_id,
  block: true,
  timeout: 120000    // 120 seconds — matches ChatGPT timeout
})
```

If `TaskOutput` times out, mark Claude as failed and continue with other models.
Write error marker: `{"error": "timeout", "model": "claude"}` to `claude-raw.json`.

### Step 2.1.1: Read LLM Output (Use Read tool, NOT bash cat)

```
Wait for all models, then use Read tool (no 30K limit):

Read({ file_path: "$REVIEW_DIR/gemini-raw.txt" })
Read({ file_path: "$REVIEW_DIR/chatgpt-raw.json" })
Read({ file_path: "$REVIEW_DIR/codex-raw.txt" })
```

### Step 2.2: Wait for All Models (with per-PID status)

```bash
echo "Waiting for all models to complete..."

# Collect per-model exit status
declare -A MODEL_STATUS
for model in "${!MODEL_PIDS[@]}"; do
  pid=${MODEL_PIDS[$model]}
  if wait $pid 2>/dev/null; then
    MODEL_STATUS[$model]="success"
  else
    MODEL_STATUS[$model]="failed"
  fi
done

# Also: TaskOutput({ task_id: claude_task_id, block: true, timeout: 120000 })
# If timeout → MODEL_STATUS[claude]="failed"

PARALLEL_END=$(date +%s)
TOTAL_PARALLEL_TIME=$((PARALLEL_END - PARALLEL_START))

# Generate model availability report
RESPONDED=0
FAILED=0
for model in "${!MODEL_STATUS[@]}"; do
  if [[ "${MODEL_STATUS[$model]}" == "success" ]]; then
    RESPONDED=$((RESPONDED + 1))
    echo "  ✅ $model: success"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $model: failed/timeout"
  fi
done

echo ""
echo "All models completed in ${TOTAL_PARALLEL_TIME}s (wall clock)"
echo "Responded: $RESPONDED  Failed: $FAILED"
```

### Step 2.3: Collect Timing Data

```bash
GEMINI_LATENCY=$(cat $REVIEW_DIR/gemini-latency.txt 2>/dev/null || echo 0)
CHATGPT_LATENCY=$(cat $REVIEW_DIR/chatgpt-latency.txt 2>/dev/null || echo 0)
CODEX_LATENCY=$(cat $REVIEW_DIR/codex-latency.txt 2>/dev/null || echo 0)

cat > $REVIEW_DIR/timing.json << EOF
{
  "execution_mode": "parallel",
  "wall_clock_seconds": ${TOTAL_PARALLEL_TIME},
  "models_with_file_access": ["claude", "gemini", "codex"],
  "models_without_file_access": ["chatgpt"],
  "timings": {
    "gemini": { "method": "local-cli", "latency_ms": ${GEMINI_LATENCY}, "file_access": true },
    "chatgpt": { "method": "remote-api", "latency_ms": ${CHATGPT_LATENCY}, "file_access": false },
    "codex": { "method": "local-cli", "latency_ms": ${CODEX_LATENCY}, "file_access": true }
  },
  "recorded_at": "$(date -Iseconds)"
}
EOF
```

---

## Phase 3: Collect & Parse Results

### Step 3.0: Validate Raw Output (JSON health check)

Before parsing, validate each model's raw output file:

```bash
# Validate JSON outputs
for f in $REVIEW_DIR/chatgpt-raw.json $REVIEW_DIR/claude-raw.json; do
  if [[ -f "$f" ]]; then
    if jq empty "$f" 2>/dev/null; then
      echo "✅ $(basename $f): valid JSON"
    else
      echo "⚠️ $(basename $f): INVALID JSON — marking model as failed"
      # Mark this model's result as unparseable
    fi
  fi
done

# For text outputs (gemini, codex), check for error markers
for f in $REVIEW_DIR/gemini-raw.txt $REVIEW_DIR/codex-raw.txt; do
  if [[ -f "$f" ]] && head -1 "$f" | jq -e '.error' &>/dev/null; then
    echo "⚠️ $(basename $f): contains error marker — model failed"
  fi
done
```

```
Step 3.1: Parse Model Responses
  Gemini CLI: Extract JSON from response.response field or markdown code block
  Remote APIs: Extract from choices[0].message.content
  Claude: Already structured from Task output

Step 3.2: Handle Parse Failures
  If JSON invalid, attempt regex extraction
  Log parsing errors
  Continue with successfully parsed results
```

## Phase 4: Aggregate Results

Use the weighted consensus algorithm from `multi-model/aggregators/weighted-consensus.md`.

```
Step 4.1: Normalize Findings
  Generate canonical finding IDs (see weighted-consensus.md)
  Group identical/similar findings across models

Step 4.2: Calculate Consensus
  Count models agreeing on each finding
  Classify: confirmed (>=0.75), likely (0.50-0.74), disputed (0.30-0.49), unique (<0.30)

Step 4.3: Claude Arbitration
  For disputed/high-severity findings:
    Read actual code at referenced location
    Compare spec vs implementation
    Final determination: confirmed/rejected/modified

Step 4.4: Generate Aggregated Report
  Create aggregated-report.json (schema: multi-model/schemas/aggregated-report.schema.json)
```

## Phase 5: Generate Report & Output

**Obey Context Conservation Policy** (see `multi-model/context-conservation.md`).

```
Step 5.1: Create final-report.md (WRITE TO FILE, not conversation)
  Executive summary, timing, consensus matrix, arbitration, recommendations

Step 5.2: Move to completed
  mv .dev/reviews/in-progress/{id} .dev/reviews/completed/{id}

Step 5.3: Output ONLY compact summary to conversation (< 500 tokens)

Step 5.4: Shadow Mode Comparison (Optional)
  If A/B testing is active, compare Claude-only baseline against consensus:
  - Save Claude findings as baseline-claude.json (copy from claude-raw.json)
  - Compute EVS (Ensemble Value Score) = ensemble_only_catches / total_confirmed
  - Append EVS to metrics-history.jsonl
  - See: analysis/ab-testing-framework.md § Shadow Mode Protocol

Step 5.5: Collect Effectiveness Metrics
  Append timing + quality + cost metrics to .dev/reviews/metrics-history.jsonl
  - See: metrics-collection.md § Mandatory Metrics
```

### Compact Summary Format

```
+================================================================+
|             MULTI-MODEL REVIEW COMPLETE                          |
+================================================================+
| Models: Claude + Gemini + ChatGPT + Codex                       |
| Total Findings: {N}                                              |
| After Arbitration: {M} confirmed                                 |
| VERDICT: PASS / FAIL ({XX}% compliance)                          |
+================================================================+
| Critical Issues (if any, max 5):                                 |
|  [F001] Brief description                                        |
+================================================================+
| Full Report: .dev/reviews/completed/{id}/final-report.md         |
+================================================================+
```

---

## Mandatory Execution Checkpoint

Before proceeding to Phase 3, verify ALL 4 LLMs were actually called:

| LLM | Method | Command | Output File |
|-----|--------|---------|-------------|
| Claude | Task tool | `Task({run_in_background})` | claude-raw.json |
| Gemini | Local CLI | `cat prompt \| gemini -y` | gemini-raw.txt |
| ChatGPT | Remote API | `curl api.openai.com/...` | chatgpt-raw.json |
| Codex | Local CLI | `cat prompt \| codex exec -` | codex-raw.txt |

**Violation**: Only Claude sub-agents used (no external CLI calls) = INVALID. Must re-execute.

---

## Prerequisites Check

> **Note**: Prerequisites are now verified in **Phase 1 (Pre-flight Availability Check)** above.
> The pre-flight check builds an `AVAILABLE_MODELS` array and aborts if fewer than
> `MIN_MODELS` (default 3) are available. Manual verification is no longer needed.
