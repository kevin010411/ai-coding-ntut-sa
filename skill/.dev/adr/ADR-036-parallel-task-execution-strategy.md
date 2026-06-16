# ADR-020: 平行任務執行策略

## 狀態
已接受

## 背景
目前使用 sub-agent workflow prompts 來執行任務，但這些都是循序執行的。當有多個獨立的功能需要開發時（例如 RenameSprint、ChangeSprintGoal、SetSprintTimebox），循序執行會花費大量時間（3個功能約90分鐘）。

Claude Code 的 Task tool 支援並行執行，但需要適當的配置來管理任務群組、依賴關係和執行順序。

## 決策
建立平行執行配置系統，允許定義任務群組並指定執行策略：

1. **配置檔案格式**：使用 JSON 格式定義任務群組和執行策略
2. **執行模式**：
   - `PARALLEL`: 所有任務群組同時執行
   - `SEQUENTIAL`: 任務群組依序執行
   - `MIXED`: 根據依賴關係決定執行順序
3. **任務群組**：將相關任務組織成群組（如 use case、controller、frontend）
4. **依賴管理**：支援定義群組間的依賴關係

## 實作細節

### 配置檔案結構
```json
{
  "version": "1.0",
  "name": "任務名稱",
  "executionMode": "PARALLEL",
  "taskGroups": [
    {
      "groupId": "unique-id",
      "type": "USE_CASE",
      "tasks": [...]
    }
  ],
  "dependencies": {},
  "notifications": {}
}
```

### 檔案組織
```
.ai/parallel-execution/
├── README.md           # 使用說明
├── schema.json        # JSON Schema 定義
├── configs/           # 配置檔案目錄
│   └── *.json        # 各種配置
└── validate-config.sh # 驗證腳本
```

### 執行方式
1. 創建配置檔案
2. 驗證配置：`.ai/parallel-execution/validate-config.sh <config>`
3. 執行：`execute-parallel <config>` 或在 Claude Code 中指定

## 優勢
1. **效率提升**：3個獨立功能從90分鐘縮短到30分鐘（3x提升）
2. **資源利用**：充分利用 Claude Code Task tool 的並行能力
3. **靈活性**：支援不同的執行策略（平行、循序、混合）
4. **可維護性**：配置檔案易於理解和修改
5. **進度追蹤**：每個任務群組的狀態都可追蹤

## 使用時機
- 多個獨立功能需要同時開發
- 功能之間沒有依賴關係
- 需要加速開發流程
- 大型 end-to-end 任務

## 範例
`rename-change-goal-and-timebox.json`：同時執行三個 Sprint 功能的開發，每個功能包含 use case、controller 和 frontend 三個部分。

## 注意事項
1. 確保任務之間真的是獨立的，避免資源衝突
2. 設定合理的 `maxParallelGroups` 避免系統過載
3. 使用通知功能追蹤執行進度
4. 定期驗證配置檔案的正確性

## 相關決策
- ADR-004: Sub-agent 架構（保持 prompt-based，但支援平行執行）
- ADR-005: AI Task 執行 SOP（每個任務仍需遵循 SOP）
- ADR-019: 任務完成通知機制（整合語音通知）

## 日期
2025-08-21