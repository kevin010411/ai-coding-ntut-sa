# ADR-004: Sub-agent 架構決策 - Prompt-based vs Claude Code Task

## 狀態
**已決定** - 2025-08-15

## 背景
專案建立了 Sub-agent Workflow 系統來提高程式碼生成品質，需要決定使用哪種實作方式：
1. Prompt-based system（目前實作）- 使用 markdown 檔案定義 prompts
2. Claude Code Task tool - 使用內建的 sub-agent 功能

## 決策
**維持現有的 Prompt-based Sub-agent 系統**，不改用 Claude Code 的 Task tool。

## 原因

### Claude Code Task Tool 限制

#### 1. 只支援 3 種內建 subagent_type
```python
subagent_type = "general-purpose"     # 通用型任務
subagent_type = "statusline-setup"    # 狀態列設定
subagent_type = "output-style-setup"  # 輸出樣式設定
```
**問題**：無法建立專門的 `code-generation`、`test-generation`、`code-review` 等自訂類型。

#### 2. 無法載入自訂 Prompt 檔案
```python
# ❌ 不支援的功能
Task(
    subagent_type="general-purpose",
    prompt_file=".ai/tech-stacks/java-ezddd-spring/prompts/code-generation-prompt.md"  # 無法載入
)

# ❌ 也無法這樣做
Task(
    subagent_type="custom",
    instructions=read(".ai/tech-stacks/java-ezddd-spring/prompts/...")  # 無法註冊新類型
)
```

#### 3. 無法傳遞專案特定知識
本專案使用的特殊框架和規範無法傳遞給 general-purpose sub-agent：
- **ezDDD 框架**：Event Sourcing DDD 框架（非標準）
- **ezSpec 測試框架**：BDD 測試框架（非標準）
- **特定驗證規則**：Aggregate 用 `Contract.requireNotNull`，Value Object 用 `Objects.requireNonNull`
- **特定 package 結構**：根據 ADR-001 的扁平結構
- **Inner class 規範**：UseCase Input 和 Controller Request/Response 必須是 inner class

#### 4. Sub-agent 是獨立實例（無共享 Context）
```python
# 為什麼這個不會運作
Task(
    prompt="根據 .ai/tech-stacks/java-ezddd-spring/prompts/code-generation-prompt.md 產生程式碼",
    subagent_type="general-purpose"
)
```
**技術原因**：
- Sub-agent 是**全新的 Claude 實例**，沒有主對話的 context
- Sub-agent 不知道專案結構和檔案位置
- Sub-agent 必須自己探索檔案系統（可能找錯或失敗）
- 無法保證正確讀取和理解 prompt 檔案

**執行流程問題**：
```
主 Claude (有完整 context) → Task() → Sub-agent (空白 context)
                                         ↓
                                    不知道 .ai/tech-stacks/java-ezddd-spring/prompts/ 是什麼
                                    不知道專案結構
                                    必須重新探索
```

#### 5. 無法嵌入大型 Prompt 檔案
```python
# 理論可行但不實用
Task(
    prompt="[500+ 行的 prompt 內容...]",  # 維護噩夢
    subagent_type="general-purpose"
)
```
**問題**：
- 檔案內容太大（500+ 行）
- 失去版本控制優勢
- 每次更新都要修改程式碼
- Context 使用效率極差

#### 6. 實際執行比較
```markdown
# Claude Code Task (無法客製化)
Task(
    subagent_type="general-purpose",
    prompt="實作 CreateProduct use case"
)
結果風險：
- 不知道要用 ezddd 框架
- 不知道 Input 要是 inner class
- 不知道驗證方式的差異
- 可能產生完全錯誤的結構

# Prompt-based (完全可控)
根據 .ai/tech-stacks/java-ezddd-spring/prompts/code-generation-prompt.md 產生程式碼
結果保證：
- 遵循 ezddd 框架規範
- Input 正確實作為 inner class
- 使用正確的驗證方式
- 符合所有 coding standards
```

### Prompt-based 系統優勢
1. **完全可控** - 精確定義每個 prompt 內容
2. **易於維護** - 修改 `.md` 檔案即可更新行為
3. **版本控制** - prompt 檔案可以 git 追蹤
4. **透明度高** - 可以看到完整執行過程
5. **符合需求** - 可以精確遵循 coding standards
6. **Context 共享** - 在同一對話 context 中執行，CLAUDE.md 資訊不會遺失

### 效益比較

| 面向 | Prompt-based (現在) | Real Sub-agents | 
|------|-------------------|-----------------|
| **客製化程度** | 🟢 高 | 🔴 低 |
| **執行效率** | 🟡 中 (串列) | 🟢 高 (平行) |
| **Context 使用** | 🔴 高 | 🟢 低 |
| **維護成本** | 🟢 低 | 🟡 中 |
| **透明度** | 🟢 高 | 🔴 低 |
| **自動化** | 🔴 低 | 🟢 高 |

## 影響

### 正面影響
- ✅ 保持現有靈活性和可控性
- ✅ 不需要重寫整個系統
- ✅ 持續支援精確的程式碼生成規則
- ✅ Prompt 檔案可持續優化和版本管理

### 負面影響
- ❌ Context 會持續累積（可透過明確指令管理）
- ❌ 無法真正平行執行（影響有限）
- ❌ 需要手動觸發特定 prompt（可透過 workflow 改善）

## 優化建議

### 1. 減少 Context 累積
```markdown
# 在對話中明確指示
"清除前面的 context，只保留必要結果"
```

### 2. 模擬平行執行
```markdown
# 在單一請求中要求多個任務
同時執行：
1. 根據 code-generation-prompt.md 產生程式碼
2. 根據 ezspec-test-generation-prompt.md 產生測試
```

### 3. 自動化觸發
- 在 task 檔案的 `pipeline.steps` 中明確指定使用哪些 prompts
- 建立標準執行流程文件

## 實作細節

### 現有檔案結構（保持不變）
```
.ai/
├── prompts/
│   ├── code-generation-prompt.md
│   ├── ezspec-test-generation-prompt.md
│   ├── code-review-prompt.md
│   ├── controller-code-generation-prompt.md
│   ├── controller-test-generation-prompt.md
│   └── controller-code-review-prompt.md
└── SUB-AGENT-SYSTEM.md
```

### 使用方式
```markdown
# 簡單任務
直接執行 task-[name]

# 複雜任務
請使用 sub-agent workflow 實作 [task-name]
```

## 替代方案（已評估）

### 方案：改用 Claude Code Task tool
- **優點**：真正的平行執行、獨立 context、自動化程度高
- **缺點**：
  - 無法載入專案的 prompt 檔案
  - 無法傳遞 ezDDD/ezSpec 框架知識
  - general-purpose agent 不理解專案特定規範
  - 輸出品質無法保證符合 coding standards
- **結論**：Claude Code 的 sub-agents 是為通用任務設計，不適合需要高度客製化的專案

### 關鍵決策因素
本專案有**高度特定的技術棧**，需要精確控制程式碼生成：
1. 使用非標準框架（ezDDD、ezSpec、uContract）
2. 有嚴格的 coding standards 和設計模式
3. 需要特定的驗證規則（Contract vs Objects）
4. 有明確的架構決策（ADR-001、ADR-002、ADR-003）

這些需求無法透過 Claude Code 的通用 sub-agents 滿足。

### 技術架構差異
```yaml
Claude Code 架構:
  主 Assistant:
    - 有完整對話 context
    - 知道所有檔案內容
    - 理解專案結構
    
  Sub-agent (Task):
    - 全新的 context（獨立實例）
    - 必須自己探索檔案系統
    - 沒有預先知識
    - 無法共享主對話的資訊

Prompt-based 架構:
  單一 Assistant:
    - 共享所有 context
    - 直接讀取 prompt 檔案
    - 保持知識連貫性
    - 可累積學習
```

這種架構差異決定了 Claude Code sub-agents 無法滿足需要大量領域知識和客製化規則的專案。

## CLAUDE.md 內容重組

### 重組前後對比
- **重組前**：CLAUDE.md 包含 1087 行，所有規範集中在單一檔案
- **重組後**：CLAUDE.md 精簡至 117 行（減少 89%），詳細規範分散到專門檔案

### 內容遷移對照表

| 原 CLAUDE.md 內容 | 遷移位置 | 目的 |
|------------------|----------|------|
| 詳細編碼規範 | `.ai/tech-stacks/java-ezddd-spring/prompts/code-generation-prompt.md` | 專門處理程式碼生成 |
| 測試撰寫指引 | `.ai/tech-stacks/java-ezddd-spring/prompts/ezspec-test-generation-prompt.md` | 專門處理測試生成 |
| Code Review 規則 | `.ai/tech-stacks/java-ezddd-spring/prompts/code-review-prompt.md` | 專門處理審查 |
| Domain Event 細節 | `coding-standards/aggregate-standards.md` | 模組化規範 |
| Use Case 實作細節 | `coding-standards/usecase-standards.md` | 模組化規範 |
| Repository 規範 | `coding-standards/repository-standards.md` | 模組化規範 |
| 測試策略詳細 | `coding-standards/test-standards.md` | 模組化規範 |

### 資訊傳遞機制
**重要發現**：因為使用 Prompt-based 系統而非真正的 sub-agents，資訊不會遺失：

```markdown
執行流程：
1. AI 助手讀取 CLAUDE.md（獲得專案記憶）
2. AI 助手讀取對應的 prompt 檔案（獲得特定規則）
3. 在同一個 context 中執行（資訊累積）
4. CLAUDE.md 的重要資訊（如 Maven 路徑、版本號）仍然可用
```

**如果是真正的 sub-agents（會有問題）**：
```markdown
1. 主 AI 讀取 CLAUDE.md
2. Task() → 新 sub-agent（看不到 CLAUDE.md）
3. 資訊斷層，可能遺失關鍵配置
```

### 優缺點分析

**優點**：
- ✅ 模組化：每個 prompt 專注單一任務
- ✅ 易維護：修改特定規則不影響其他部分
- ✅ 版本控制：可追蹤各部分獨立變更
- ✅ 減少重複：避免同樣規則出現多處

**潛在風險**：
- ⚠️ Context 分散：需要讀取多個檔案
- ⚠️ 一致性挑戰：prompt 之間可能不一致
- ⚠️ 依賴 Prompt-based 架構：如果改用真正的 sub-agents 會有資訊遺失問題

## 參考文件
- [SUB-AGENT-SYSTEM.md](./SUB-AGENT-SYSTEM.md)
- [Prompt 檔案目錄](./prompts/)
- [CLAUDE.md](../CLAUDE.md) - 專案記憶體

## 決策者
AI 助手與使用者共同評估決定

## 更新歷史
- 2025-08-15：初始決策，維持 Prompt-based 系統
- 2025-08-15：加入 Claude Code 限制的詳細技術解釋
- 2025-08-15：加入 Sub-agent 獨立實例架構的技術細節
- 2025-08-15：加入 CLAUDE.md 內容重組分析和資訊傳遞機制說明