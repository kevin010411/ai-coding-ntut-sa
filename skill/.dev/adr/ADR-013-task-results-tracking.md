# ADR-013: Task Results Tracking Enforcement

## Status
Accepted

## Context
AI 助手在執行 task 時經常忘記將執行結果寫回 task JSON 檔案的 results 陣列，導致：
1. 無法追蹤 task 執行歷史
2. 無法驗證 task 是否真的完成
3. 團隊協作時缺少執行記錄

## Decision
實施強制性的 Task 執行結果追蹤機制：

### 1. TodoWrite 強制追蹤
每次執行 task 時，必須使用 TodoWrite 建立以下追蹤清單：
```
1. [ ] 讀取 task 檔案
2. [ ] 執行所有 pipeline.steps
3. [ ] 執行 postChecks
4. [ ] 更新 task results 陣列 ⚠️
5. [ ] 更新 task status 欄位 ⚠️
6. [ ] 驗證結果已寫入檔案
```

### 2. 自動化檢查腳本
- **位置**: `.ai/hooks/task-completion-check.sh`
- **功能**: 檢查最近修改的 task 檔案是否有正確更新 results
- **執行時機**: 
  - 每次 commit 前（透過 git hook）
  - AI 完成 task 後手動執行

### 3. CLAUDE.md 更新
在 CLAUDE.md 中加入強制 SOP，明確標示步驟 4 和 5 為【重要】步驟

### 4. Results 陣列必要欄位
```json
{
  "completionDateTime": "ISO 8601 格式完成時間（必要）",
  "totalImplementationTime": "總執行時間，如 '45 minutes'（必要）",
  "status": "done|failed|partial",
  "summary": "執行摘要",
  "outputFiles": ["產生或修改的檔案列表"],
  "changes": ["具體變更說明"],
  "testResults": "測試結果（如適用）",
  "postChecksResults": { "檢查結果物件" }
}
```

**兩個必要欄位說明**：
1. **completionDateTime**: 必須記錄任務完成的精確時間，使用 ISO 8601 格式（含時區）
2. **totalImplementationTime**: 必須記錄從開始執行到完成的總時間，便於評估效率

## Consequences

### Positive
- 確保每個 task 都有完整的執行記錄
- 提高 AI 助手的可靠性和一致性
- 便於追蹤和審計 task 執行歷史
- 團隊協作時有清晰的執行記錄

### Negative
- 增加 AI 執行 task 的步驟
- 需要額外的驗證時間
- 可能稍微降低執行速度

## Implementation Checklist
- [x] 更新 CLAUDE.md 加入強制 SOP
- [x] 建立 task-completion-check.sh 檢查腳本
- [x] 記錄此 ADR
- [ ] 設定 git pre-commit hook（選擇性）

## Enforcement Rules
1. **硬性規定**: 任何 task 執行後，status 變更為 done/in-progress 時，results 陣列不能為空
2. **TodoWrite 追蹤**: 必須使用 TodoWrite 追蹤所有步驟
3. **最終驗證**: 執行結束前必須用 `cat` 或 `grep` 確認 results 已寫入

## Example Workflow
```bash
# 1. 開始執行 task
TodoWrite: 建立 6 個追蹤項目

# 2. 執行 task 步驟
... 執行程式碼 ...
TodoWrite: 標記步驟 1-3 為 completed

# 3. 更新 results
Edit task-xxx.json
TodoWrite: 標記步驟 4-5 為 completed

# 4. 驗證
cat .dev/tasks/xxx/task-xxx.json | grep -A 10 results
TodoWrite: 標記步驟 6 為 completed

# 5. 執行檢查腳本
.ai/hooks/task-completion-check.sh
```

---
Date: 2025-08-17
Author: Claude with User