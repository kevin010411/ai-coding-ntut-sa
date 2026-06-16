# Headless Mode (`claude -p`) — CI/CD 參考

## 基本語法

```bash
# 非互動模式，執行完自動退出
claude -p "Your prompt here"

# 限制工具 + JSON 輸出 + 成本上限
claude -p "Your prompt" \
  --allowedTools "Read,Grep,Bash" \
  --output-format json \
  --max-turns 10 \
  --max-budget-usd 5.00
```

## 關鍵 Flags

| Flag | 用途 | 範例 |
|------|------|------|
| `-p, --print` | 非互動模式 | `claude -p "analyze"` |
| `--allowedTools` | 自動核准工具（不會跳權限提示） | `"Read,Grep,Bash"` |
| `--output-format` | `text` / `json` / `stream-json` | `--output-format json` |
| `--max-turns` | 限制 agent 回合數 | `--max-turns 10` |
| `--max-budget-usd` | 成本上限 | `--max-budget-usd 5.00` |
| `--append-system-prompt` | 附加系統指令 | `--append-system-prompt "Focus on security"` |
| `--continue` | 延續上次對話 | `claude -p "next step" --continue` |

## 本專案實用範例

### 1. PR 自動 Code Review

```bash
# 取得 PR 變更的檔案，讓 Claude 審查
FILES=$(git diff --name-only origin/main HEAD | tr '\n' ' ')
claude -p "Review these changed files for security issues, Clean Architecture violations, and missing tests: $FILES" \
  --allowedTools "Read,Grep" \
  --output-format json \
  --max-turns 5 \
  --max-budget-usd 2.00
```

### 2. E2E 測試覆蓋率檢查

```bash
claude -p "Check which React components in frontend/src/pages/ lack E2E test coverage in frontend/tests/e2e/. List uncovered components with suggested test cases." \
  --allowedTools "Read,Grep,Glob" \
  --output-format json \
  --max-turns 5
```

### 3. Doc Audit（取代手動跑 python3）

```bash
claude -p "Run python3 .claude/scripts/audit-docs.py and fix any dead links found in CLAUDE.md" \
  --allowedTools "Read,Bash,Edit" \
  --max-turns 8
```

## 限制

- `/skill` 指令在 headless 模式下不可用 — 要直接描述任務
- 無法互動詢問 — 用 `--append-system-prompt` 預先提供完整上下文
- 需設定 `ANTHROPIC_API_KEY` 環境變數
