# ADR-019: 平行任務執行策略

## 狀態
已採納 (Accepted)

## 背景
在開發過程中，經常遇到需要實作多個獨立功能的情況，例如 Sprint 管理的 Rename、SetGoal、SetTimebox 功能。這些功能彼此獨立，沒有相互依賴，如果按順序執行會浪費時間。

目前的執行模式是串行的：
- 步驟 1-3: RenameSprint (use case → controller → frontend)
- 步驟 4-6: SetSprintGoal (use case → controller → frontend)  
- 步驟 7-9: SetSprintTimebox (use case → controller → frontend)

串行執行需要 9 個步驟的時間，但實際上這三組功能可以同時開發。

## 決策
採用**平行任務執行策略**，允許在任務文件中指定平行執行模式，讓 AI 可以同時啟動多個 sub-agent 來處理獨立的功能群組。

### 支援的執行模式
1. **SEQUENTIAL**（預設）：按順序逐步執行
2. **PARALLEL**：多個群組同時執行
3. **HYBRID**：部分平行，部分順序（未來擴充）

### 平行執行的觸發方式
1. **Markdown 格式**：使用 `**IN PARALLEL**` 標記
2. **JSON 格式**：設定 `"executionMode": "PARALLEL"`
3. **關鍵字觸發**：`Execute in parallel:`, `同時執行:`, `平行處理:`
4. **群組標記**：`**Parallel Group A/B/C:**`

### 任務檔案結構
```json
{
  "executionMode": "PARALLEL",
  "parallelGroups": [
    {
      "groupId": "group-1",
      "subAgentType": "command-sub-agent",
      "steps": [...]
    }
  ]
}
```

## 理由
1. **效率提升**：3 個獨立功能可以從 9 步驟時間縮短到 3 步驟時間
2. **資源利用**：充分利用 AI sub-agent 的並行處理能力
3. **開發體驗**：減少等待時間，更快看到完整功能
4. **靈活性**：可根據任務特性選擇適合的執行模式

## 適用場景
### 適合平行執行
- 多個獨立的 CRUD 操作
- 不同 Aggregate 的功能開發
- 獨立的前後端功能模組
- 多個 Use Case 的實作

### 不適合平行執行
- 有依賴關係的功能（B 需要 A 的輸出）
- 會修改同一檔案的任務
- 順序敏感的操作流程

## 實作細節
1. **Sub-agent 類型**
   - `command-sub-agent`: Command use case 實作
   - `query-sub-agent`: Query use case 實作
   - `reactor-sub-agent`: Reactor 事件處理
   - `controller-sub-agent`: REST Controller 實作
   - `aggregate-sub-agent`: DDD Aggregate 實作

2. **執行追蹤**
   - 使用 TodoWrite 追蹤各群組進度
   - 記錄每個群組的開始/結束時間
   - 計算相對於串行執行的加速比

3. **錯誤處理**
   - 某個群組失敗不影響其他群組繼續執行
   - 失敗的群組單獨標記和報告
   - 提供重試機制

## 範例
### RenameSprint, SetSprintGoal, SetSprintTimebox
```markdown
Execute the following tasks **IN PARALLEL**:

**Parallel Group A: RenameSprint**
- Implement use case and tests
- Implement controller
- Add frontend support

**Parallel Group B: SetSprintGoal**
- Implement use case and tests
- Implement controller
- Add frontend support

**Parallel Group C: SetSprintTimebox**
- Implement use case and tests
- Implement controller
- Add frontend support
```

執行結果：
- 串行執行：約 90 分鐘（9 步驟 × 10 分鐘）
- 平行執行：約 30 分鐘（3 步驟並行）
- 加速比：3x

## 後果
### 正面影響
- 開發效率提升 2-3 倍
- 更快的功能交付
- 更好的資源利用
- 減少開發者等待時間

### 負面影響
- 需要仔細規劃避免檔案衝突
- 可能增加 merge conflict 風險
- 需要更多的協調和管理
- 初期學習曲線

### 風險緩解
- 明確標記可平行執行的任務
- 提供清晰的文檔和範例
- 建立標準模板
- 自動檢測潛在衝突

## 相關文件
- `.dev/templates/parallel-task-template.json` - 平行任務模板
- `.dev/docs/PARALLEL-EXECUTION-GUIDE.md` - 平行執行指引
- `.dev/tasks/feature/sprint/task-rename-change-goal-and-timebox-parallel.json` - 範例任務

## 決策日期
2025-01-20

## 參與者
- AI Assistant (Claude)
- 開發團隊

## 修訂歷史
- 2025-01-20: 初始版本，建立平行執行策略