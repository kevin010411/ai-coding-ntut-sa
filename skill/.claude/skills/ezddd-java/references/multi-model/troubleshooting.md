# Multi-Model Troubleshooting

## Gemini CLI Issues

| Error | Solution |
|-------|----------|
| Not installed | `which gemini` should return `gemini` |
| Authentication failed | Run: `gemini auth login` |
| `-o json` causes issues | Use `-y` only: `cat file \| gemini -y` |
| Quota exceeded | Local CLI has unlimited quota (uses local credentials) |

## ChatGPT API Issues

| Error | Solution |
|-------|----------|
| `You didn't provide an API key` | Run `source ~/.zshrc` before calling API |
| `invalid_api_key` | Check API key format: `sk-...` (164 chars) |
| JSON parsing error | Use `jq` to build request: `jq -n --arg content "$PROMPT" '{...}'` |
| Rate limit (429) | Wait 60 seconds and retry |
| No file access | Include full code in prompt |

## Codex CLI Issues

| Error | Solution |
|-------|----------|
| `--reasoning-effort` not found | Use `codex exec --full-auto -` (no reasoning-effort flag) |
| Model not supported | Don't specify `-m o4-mini`, use default `gpt-5-codex` |
| Prompt not read | Use pipe input: `cat file \| codex exec --full-auto -` |

## Common Patterns

**Always use pipe input for CLI tools:**

```bash
# Correct - pipe input
cat prompt.txt | gemini -y
cat prompt.txt | codex exec --full-auto -

# Wrong - command-line argument
gemini -y "$(cat prompt.txt)"                  # May work but risky
codex exec --full-auto "$(cat prompt.txt)"     # Shell escaping issues
```

## Timeout & Degradation Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| `{"error": "timeout", "model": "..."}` in raw file | Model exceeded timeout limit | Increase timeout in `project-config.json` → `degradation.timeouts` |
| `ABORT: Only N models available, minimum is 3` | Too few models installed | Install missing CLI tools or lower `min_models` |
| `Running in partial mode (N / 4 models)` | Some models unavailable | Install missing tools; review is valid but with fewer perspectives |
| ChatGPT 429 after retries | Rate limit exhausted | Wait a few minutes, or reduce concurrent API usage |
| Claude sub-agent timeout | Task tool took too long | Check if main agent has enough context budget |

### Degraded Mode Behavior

When fewer than 4 models respond, the system adapts:

| Responding | Mode | What Changes |
|-----------|------|-------------|
| 4 | Normal | Full weighted consensus |
| 3 | Partial | Consensus formula uses only responding weights; warning in report |
| 2 | Degraded | Claude arbitrates ALL findings (no consensus voting) |
| 1 | Single | Reported as single-model review; no consensus analysis |
| 0 | Failure | No report generated; abort |

The `degradation` field in the output report shows which mode was used and which models failed.

## Output Handling

Bash tool has 30000 char limit. All LLM outputs MUST:
1. Write to files (don't rely on stdout)
2. Use **Read tool** to read results (no char limit)
3. Avoid `cat` on large files in bash

```
# Correct: Read tool (no limit)
Read({ file_path: "$REVIEW_DIR/gemini-raw.txt" })

# Wrong: bash cat (truncated at 30K)
cat $REVIEW_DIR/codex-raw.txt
```
