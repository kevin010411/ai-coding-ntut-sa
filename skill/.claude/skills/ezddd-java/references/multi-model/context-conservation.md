# Context Conservation Policy

**Purpose**: Prevent context bloat that exhausts Claude session quota too quickly.

## Mandatory Rules

1. **All LLM raw outputs MUST be written to files** — never printed in conversation
2. **Conversation output limited to compact summary** (< 500 tokens)
3. **Remind user to clean context** after completion

## Output Format (MUST follow)

After multi-model review completes, output ONLY this format in conversation:

```
+================================================================+
|             MULTI-MODEL REVIEW COMPLETE                          |
+================================================================+
| Models: Claude + Gemini + ChatGPT + Codex                       |
| Total Findings: N                                                |
| After Arbitration: M confirmed                                   |
| VERDICT: PASS / FAIL (XX% compliance)                            |
+================================================================+
| Critical Issues (if any):                                        |
|  [F001] Brief description                                        |
|  [F002] Brief description                                        |
+================================================================+
| Full Report: .dev/reviews/completed/{id}/final-report.md         |
| Raw Data: .dev/reviews/completed/{id}/                           |
+================================================================+

Suggest: Run /clear or /compact to free context.
```

## Prohibited

- Do NOT print full `gemini-raw.txt` content in conversation
- Do NOT print full `chatgpt-raw.json` content in conversation
- Do NOT print full `codex-raw.txt` content in conversation
- Do NOT print more than 5 findings (say "see full report" for the rest)

## User Wants Full Report?

Guide them to read the file directly:

```
To see the full report:
cat .dev/reviews/completed/{id}/final-report.md
```
