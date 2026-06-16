# ADR-007: Task 檔案格式標準化

## 狀態
已採納 (Accepted)

## 日期
2025-08-15

## 背景 (Context)

在專案開發過程中，我們使用 task 檔案來定義和追蹤開發任務。然而，我們發現：

1. **格式不一致問題**：UseCase 層和 Adapter 層的 task 檔案格式存在差異，但沒有明確的規範文件
2. **範本缺失**：沒有標準的 task 檔案範本，導致開發者可能參考錯誤的範例（如參考已完成的 task 而非待執行的 task）
3. **狀態值混淆**：初始狀態值使用不一致（`pending` vs `todo`）
4. **層級特定差異**：不同層級（UseCase vs Controller）的 task 檔案有不同的欄位和工作流程

實際案例：在創建 Sprint Controller task 檔案時，因參考了錯誤的範例（已完成的 task），導致產生了包含過多執行結果資訊的錯誤格式。

## 決策 (Decision)

我們決定：

1. **建立標準化的 Task 檔案範本**
   - 為 UseCase 層創建專用範本：`task-usecase-template.json`
   - 為 Controller 層創建專用範本：`task-controller-template.json`
   - 保留通用範本作為參考：`task-template.json`

2. **統一初始狀態值**
   - 所有新建 task 的初始狀態統一使用 `"status": "todo"`
   - 狀態流程：`todo` → `in_progress` → `done` (或 `blocked`/`cancelled`)

3. **明確層級差異**

   **UseCase 層 Task 特徵**：
   ```json
   {
     "type": "useCase",
     "spec": {
       "useCase": ".dev/specs/{aggregate}/usecase/{name}.json",
       "testTool": ".dev/specs/ezspec-test.json"
     },
     "postChecks": [{
       "name": "subAgentWorkflow",
       "required": ["codeGeneration", "testGeneration", "codeReview"]
     }]
   }
   ```

   **Controller 層 Task 特徵**：
   ```json
   {
     "type": "restController",
     "spec": {
       "restController": ".dev/specs/{aggregate}/adapter/{name}.json"
     },
     "workflow": "controller-sub-agent",
     "postChecks": [{
       "name": "controllerSubAgentWorkflow",
       "required": ["controllerCodeGeneration", "controllerTestGeneration", "controllerCodeReview"]
     }]
   }
   ```

4. **檔案位置規範**
   - UseCase task：`.dev/tasks/feature/{aggregate}/usecase/task-{name}.json`
   - Controller task：`.dev/tasks/feature/{aggregate}/adapter/task-{name}.json`
   - Test task：`.dev/tasks/test/task-{action}-{target}-test.json`
   - Refactoring task：`.dev/tasks/refactoring/task-refactor-{target}.json`
   - 範本檔案：`.ai/templates/task-*-template.json`

## 後果 (Consequences)

### 正面影響

1. **一致性提升**：所有 task 檔案遵循相同的格式規範
2. **錯誤減少**：有明確的範本可參考，減少格式錯誤
3. **開發效率**：開發者可快速創建正確格式的 task 檔案
4. **維護性**：統一的格式便於自動化處理和批次操作
5. **清晰的層級區分**：UseCase 和 Controller 層的差異明確記錄

### 負面影響

1. **學習成本**：需要了解不同層級的 task 格式差異
2. **遷移工作**：現有的 task 檔案可能需要調整格式

## 實施細節

### 已創建的範本檔案

1. `.ai/templates/task-usecase-template.json` - UseCase 層專用範本
2. `.ai/templates/task-controller-template.json` - Controller 層專用範本
3. `.ai/templates/task-template.json` - 通用參考範本

### 關鍵差異總結

| 屬性 | UseCase 層 | Controller 層 |
|------|-----------|--------------|
| type | "useCase" | "restController" |
| workflow | 無此欄位 | "controller-sub-agent" |
| spec.testTool | 有 | 無 |
| postChecks.name | "subAgentWorkflow" | "controllerSubAgentWorkflow" |
| 步驟前綴 | 無 (如 `codeGeneration`) | 有 (如 `controllerCodeGeneration`) |

### 使用指引

```bash
# 創建 UseCase task
cp .ai/templates/task-usecase-template.json .dev/tasks/feature/product/usecase/task-create-product.json

# 創建 Controller task
cp .ai/templates/task-controller-template.json .dev/tasks/feature/product/adapter/task-create-product-controller.json
```

## 參考資料

- Task 檔案範例：`.dev/tasks/*/usecase/*.json`, `.dev/tasks/*/adapter/*.json`
- Sub-agent Workflow 文件：`.ai/tech-stacks/java-ezddd-spring/SUB-AGENT-SYSTEM.md`
- 原始問題討論：2025-08-15 創建 Sprint Controller task 時的格式錯誤事件

## 更新記錄

- 2025-08-15：初始版本，建立 task 檔案格式標準化規範