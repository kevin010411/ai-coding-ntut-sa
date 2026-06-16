# ADR-009: Command、Query 與 Reactor Sub-agent 分離決策

## 狀態
Accepted (Updated 2025-08-19 to include Reactor)

## 背景
原本的 `code-generation-prompt.md` 包含了所有 Use Case 類型的實作指引，導致：
1. Prompt 過於龐大，包含太多不相關的規則
2. Command、Query 和 Reactor 的關注點混在一起
3. AI 容易混淆不同類型 Use Case 的實作模式
4. 難以針對特定類型進行優化

Reactor 作為事件驅動架構的核心元件，有其獨特的：
- 實作模式（execute(Object event) 而非 execute(Input input)）
- 測試策略（ezapp 2.0.0: `InMemoryMessageBroker`）
- 關注點（跨聚合最終一致性）

## 決策
將原本的 `code-generation-prompt.md` 分離為三個專門的 sub-agent prompts：
- `command-sub-agent-prompt.md` - 專注於 Command use cases
- `query-sub-agent-prompt.md` - 專注於 Query use cases
- `reactor-sub-agent-prompt.md` - 專注於 Reactor implementations（新增）

## 理由

### 1. 關注點分離
**Command Use Cases 關注：**
- Aggregate 狀態變更
- Domain Events 產生
- Business rules enforcement
- Transaction boundaries
- Optimistic locking

**Query Use Cases 關注：**
- Projection 設計
- DTO mapping
- 查詢優化
- 無副作用保證
- 效能考量

**Reactor 關注：**
- 跨聚合最終一致性
- Event type checking (instanceof pattern)
- MessageBus 整合
- 錯誤隔離（不讓失敗擴散）
- Read model projection (CQRS)

### 2. 減少認知負擔
- 每個 sub-agent 只需理解自己領域的規則
- 更容易遵守規範
- 降低出錯機率

### 3. 提高品質
- 更精準的程式碼生成
- 更好的測試覆蓋
- 更容易維護和更新

## 實作細節

### Command Sub-agent 重點
```
- Input validation and command structure
- Aggregate state transitions  
- Domain event generation with metadata
- Repository save operations
- Transaction management
```

### Query Sub-agent 重點
```
- Projection interface design
- Static utility mappers
- Efficient queries (avoid N+1)
- Proper null handling
- Performance optimization
```

### Reactor Sub-agent 重點
```
- execute(Object event) method implementation
- Event type checking with instanceof
- Cross-aggregate coordination
- InMemoryMessageBroker for testing (ezapp 2.0.0)
- Error isolation and graceful degradation
```

## 影響

### 正面影響
1. **更高的規範遵守率** - 專注的 prompt 更容易被遵守
2. **更少的錯誤** - 避免不同領域規則的混淆
3. **更快的開發速度** - 精準的指引減少來回修正
4. **更易維護** - 可以獨立更新各自的 prompt

### 負面影響
1. **需要維護更多檔案** - 但這是可接受的代價
2. **需要識別 Use Case 類型** - 但通常從命名就能判斷

## 使用指引

### 自動識別
系統會根據 spec 檔案的特徵自動選擇適當的 sub-agent：
- 動詞開頭（Create, Update, Delete, Estimate）→ Command sub-agent
- Get/List/Search 開頭 → Query sub-agent
- Notify/Update/Project 等事件驅動操作 → Reactor sub-agent

### 明確指定
使用者也可以明確指定：
```
"請使用 command-sub-agent workflow 實作 create-product"
"請使用 query-sub-agent workflow 實作 get-product"
"請使用 reactor-sub-agent workflow 實作 notify-sprint-to-select-backlog-item"
```

## 決策日期
- 初始決策：2025-08-15
- 加入 Reactor：2025-08-19

## 參與者
- AI Assistant (Claude)
- User

## 參考資料
- `.ai/tech-stacks/java-ezddd-spring/prompts/command-sub-agent-prompt.md`
- `.ai/tech-stacks/java-ezddd-spring/prompts/query-sub-agent-prompt.md`
- `.ai/tech-stacks/java-ezddd-spring/prompts/reactor-sub-agent-prompt.md`（新增）
- `.ai/tech-stacks/java-ezddd-spring/prompts/reactor-test-generation-prompt.md`（新增）
- `.ai/tech-stacks/java-ezddd-spring/prompts/reactor-code-review-prompt.md`（新增）
- `.ai/tech-stacks/java-ezddd-spring/SUB-AGENT-SYSTEM.md`
- CQRS Pattern
- Clean Architecture principles
- Event-Driven Architecture patterns