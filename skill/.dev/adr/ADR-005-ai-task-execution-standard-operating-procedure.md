# ADR-005 - AI Task Execution Standard Operating Procedure

## Date
2025-08-15

## Status
Accepted

## Context
AI 助手重複發生遺漏 task 檔案要求的錯誤，特別是：
- 忽略 sub-agent workflow 的完整步驟（程式碼生成、測試生成、程式碼審查）
- 沒有執行 postChecks
- 沒有更新 task results
- 看到關鍵字就直接執行，而非先讀取 task 檔案

這些錯誤模式在多個任務中重複出現（DeleteTask、CreateProductController、SetProductGoalController），顯示需要建立標準作業程序。

## Decision
建立強制性的 5 步驟 AI Task 執行標準作業程序（SOP）：

### 標準執行流程
1. **STOP AND CHECK** - 停止並檢查是否有 task 檔案
2. **FIND TASK FILE** - 使用 Glob 搜尋 task-*.json
3. **READ AND ANALYZE** - 讀取並分析 task 要求、spec、postChecks
4. **CREATE TODO LIST** - 使用 TodoWrite 建立完整執行計畫
5. **EXECUTE WITH TRACKING** - 依序執行並追蹤進度
6. **VERIFY COMPLETION** - 驗證所有步驟完成
7. **UPDATE TASK FILE** - 更新 task 檔案狀態和 results（強制步驟）

### 強制規則
- **必須**先搜尋 task 檔案，不可直接執行
- **必須**使用 TodoWrite 工具規劃所有步驟
- **必須**執行所有 workflow 步驟（不可選擇性執行）
- **必須**執行所有 postChecks
- **必須**更新 task 檔案：
  - 將 status 從 "todo" 改為 "done"
  - 在 results 陣列新增執行記錄
  - 記錄所有產生的檔案、測試結果、審查結果
  - 立即 commit 更新（訊息格式：`chore: Update task-xxx with execution results`）

## Consequences

### Positive
- ✅ 減少遺漏步驟的錯誤
- ✅ 確保完整執行 sub-agent workflow
- ✅ 提高工作品質和一致性
- ✅ 建立可追蹤的執行記錄
- ✅ 符合專案的品質要求

### Negative
- ⚠️ 執行時間可能增加（需要先搜尋和讀取檔案）
- ⚠️ 對簡單任務可能過度流程化
- ⚠️ 需要 AI 助手改變既有行為模式

### Neutral
- 📝 需要維護 AI-TASK-EXECUTION-CHECKLIST.md 文件
- 📝 使用者需要了解新的執行流程

## Alternatives Considered

### Option 1: 僅依賴提醒
- **Description**: 依靠使用者提醒 AI 執行完整流程
- **Pros**: 簡單、不需要額外流程
- **Cons**: 容易遺忘、錯誤會重複發生
- **Reason for rejection**: 已證明無效，錯誤持續發生

### Option 2: 部分自動化
- **Description**: 只在特定類型任務（如 controller）執行 SOP
- **Pros**: 較有彈性
- **Cons**: 不一致的執行標準，仍有遺漏風險
- **Reason for rejection**: 需要統一標準避免混淆

### Option 3: 完全自動化檢查
- **Description**: 建立自動化腳本強制檢查
- **Pros**: 完全避免人為錯誤
- **Cons**: Claude Code 環境限制，無法實作完整自動化
- **Reason for rejection**: 技術限制無法實現

## Related Decisions
- [ADR-004](./ADR-004-sub-agent-architecture-decision.md) - Sub-agent 架構決策
- [AI-TASK-EXECUTION-CHECKLIST.md](../../.ai/AI-TASK-EXECUTION-CHECKLIST.md)
- [SUB-AGENT-SYSTEM.md](../../.ai/tech-stacks/java-ezddd-spring/SUB-AGENT-SYSTEM.md)

## Notes
### 實施細節
1. AI 助手必須在每次任務開始時參考檢查清單
2. 使用者可以提醒 AI："請查看 AI-TASK-EXECUTION-CHECKLIST.md"
3. 此 SOP 適用於所有需要執行 task 檔案的情況

### 成功指標
- 減少 task 執行錯誤率至 0%
- 所有 sub-agent workflow 完整執行
- 所有 postChecks 被執行
- 所有 task results 被正確更新

### 錯誤案例記錄
- task-delete-task：未執行 postChecks
- task-create-product-controller：未先產生測試
- task-set-product-goal-controller：未執行完整 workflow