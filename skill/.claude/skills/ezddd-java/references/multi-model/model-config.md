# Multi-Model Configuration

## 4-Model Dispatch Table

| # | Model | Method | Command | File Access | Cost |
|---|-------|--------|---------|-------------|------|
| 1 | **Claude** (Sonnet) | Sub-agent | `Task({ model: "sonnet", run_in_background: true })` | Yes | Session tokens |
| 2 | **Gemini** | Local CLI | `cat prompt.txt \| gemini -y` | Yes (CLI tools) | Free |
| 3 | **ChatGPT** (gpt-5.2) | Remote API | `curl api.openai.com/v1/chat/completions` | No | ~$0.02/review |
| 4 | **Codex** (gpt-5-codex) | Local CLI | `cat prompt.txt \| codex exec --full-auto -` | Yes | ~$0.03/review |

**File Access Requirement**: ChatGPT API has no file access and will produce
false positives if given only spec without implementation files in the prompt.
Include full code snippets in prompts for this model.

## CLI Input Rules

**All CLI tools MUST use pipe input** (`cat file | command`), NOT command-line args:

```bash
# Correct
cat prompt.txt | gemini -y
cat prompt.txt | codex exec --full-auto -

# WRONG (may hang or have escaping issues)
gemini -y "$(cat prompt.txt)"
```

## Token Budget

| Model | Max Input Tokens | Recommended Max Prompt |
|-------|------------------|------------------------|
| Gemini 2.5 Pro | 1M tokens | ~500K chars safe |
| GPT-5.2 | 128K tokens | ~100K chars safe |

## Prerequisites

### Gemini CLI

```bash
which gemini                           # gemini
gemini --version
echo "Hello" | gemini -y   # Quick test
```

### ChatGPT API

```bash
# Add to ~/.zshrc
export OPENAI_API_KEY="sk-..."
```

### Codex CLI

```bash
which codex                            # codex
```

## project-config.json Integration

Add to `.dev/project-config.json`:

```json
{
  "multiModelReview": {
    "enabled": true,
    "models": {
      "claude": { "enabled": true, "method": "sub-agent", "model": "sonnet", "weight": 1.5 },
      "gemini": { "enabled": true, "method": "local-cli", "weight": 1.0, "file_access": true },
      "chatgpt": { "enabled": true, "method": "remote-api", "model": "gpt-5.2", "weight": 1.2, "file_access": false },
      "codex": { "enabled": true, "method": "local-cli", "model": "gpt-5-codex", "weight": 1.2, "file_access": true }
    },
    "consensus": {
      "algorithm": "weighted-consensus",
      "thresholds": { "confirmed": 0.75, "likely": 0.50, "disputed": 0.30 },
      "arbitrator": "claude"
    },
    "degradation": {
      "min_models": 3,
      "timeouts": {
        "gemini": 180,
        "chatgpt": 120,
        "codex": 180,
        "claude": 120
      },
      "retry": {
        "chatgpt_429_max_retries": 2,
        "chatgpt_429_backoff_seconds": 30
      }
    }
  }
}
```

---

## Model Performance Profiles

Historical data from 3 completed review sessions (2025-12-30 ~ 2026-01-05).

### Claude (Sonnet/Opus)

| Metric | Value |
|--------|-------|
| Avg Findings | 12 (highest) |
| Compliance Rate | 0.88 |
| Avg Latency | 45s |
| Role | Arbitrator + primary reviewer |

**Strengths**: Highest finding count, best at cross-referencing spec vs impl, handles arbitration.
**Weaknesses**: Session token cost (no direct $ but consumes context).

### Gemini 2.5 Pro

| Metric | Value |
|--------|-------|
| Avg Findings | 10 |
| Compliance Rate | 0.45 (strictest grading) |
| Avg Latency | 66s |
| Role | Large-context reviewer |

**Strengths**: 1M token window (no truncation needed), free tier, catches spec structure issues.
**Weaknesses**: Strictest grading leads to lower compliance rate (flags more potential issues).

### ChatGPT (gpt-5.2)

| Metric | Value |
|--------|-------|
| Avg Findings | 5 |
| Compliance Rate | 0.85 |
| Avg Latency | 10.7s (fastest) |
| Cost | ~$0.02/review |
| Role | Fast secondary reviewer |

**Strengths**: Fastest response, good precision, lowest false positive rate.
**Weaknesses**: No file access — must embed full code in prompt (increases prompt size).

### Codex (gpt-5-codex)

| Metric | Value |
|--------|-------|
| Avg Findings | 5 |
| Compliance Rate | 0.75 |
| Avg Latency | 113~289s (slowest) |
| Cost | ~$0.03/review |
| Role | Code-specialized deep reviewer |

**Strengths**: Code-specialized, found unique issues (e.g., boardId validation in AGG-008).
**Weaknesses**: Slowest model, determines wall clock time for parallel execution.

---

## Evaluated and Excluded Models

### Qwen 32B (qwen2.5-coder:32b) — EXCLUDED

| Metric | Value |
|--------|-------|
| Evaluated | 2025-12-30 (create-stage review) |
| Precision | 1.0 (0 false positives) |
| Recall | Low |
| F1 Score | 0.57 |
| Latency | 94~120s |
| Model Size | 20GB (Ollama) |

**Decision**: Removed from production lineup.

**Rationale**: High precision but low recall (F1=0.57) means it rarely finds false positives
but also misses many real issues. Combined with 94~120s latency (third slowest) and the
requirement for a 20GB local Ollama installation, the cost-benefit ratio is unfavorable
when 4 cloud-grade models already provide sufficient diversity.

**Evidence**: In session `create-stage-20251230-192442`, Qwen 32B found 4 findings with
0 false positives, but its unique contribution was minimal — all findings were also caught
by other models. In session `ezscrum-all-frames-20260105`, AGG-003 (SprintCommitted userId)
was confirmed by 4/5 models excluding Qwen, demonstrating the finding survives without it.

### Qwen 14B (qwen2.5-coder:14b) — NOT RECOMMENDED

| Metric | Value |
|--------|-------|
| Evaluated | 2025-12-30 (create-stage review) |
| Precision | 0.17 (5/6 false positives) |
| F1 Score | 0.18 |
| Latency | 54s |

**Verdict**: Too many false positives for production use. 5 out of 6 findings were incorrect.

---

### Degradation Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `min_models` | 3 | Minimum models required to proceed; fewer → abort |
| `timeouts.*` | varies | Per-model timeout in seconds |
| `retry.chatgpt_429_max_retries` | 2 | Max retries on HTTP 429 rate limit |
| `retry.chatgpt_429_backoff_seconds` | 30 | Backoff between 429 retries |
