# ADR-048: Mapper toDomain() 實作模式選擇

## Status

Accepted

## Context

在 Outbox Pattern 中，Mapper 負責將 Data（JPA Entity）轉換回 Domain Aggregate。這個 `toDomain()` 方法有兩種主要實作模式：

### 模式 A：合成事件模式（Synthesized Events Pattern）

從 Data 欄位合成 Domain Events，然後用 Event Sourcing 建構函數重建 Aggregate。

```java
public static Product toDomain(ProductData data) {
    List<ProductEvents> events = new ArrayList<>();

    // 從 Data 合成 ProductCreated 事件
    events.add(new ProductEvents.ProductCreated(
            productId, name, goal, note, extension,
            ProductLifecycleState.valueOf(data.getState()),  // 直接使用儲存的 state
            ...
    ));

    // 合成其他事件...

    Product aggregate = new Product(events);  // Event Sourcing 建構函數
    aggregate.clearDomainEvents();
    return aggregate;
}
```

### 模式 B：業務建構函數模式（Business Constructor Pattern）

使用業務建構函數和業務方法重建 Aggregate，確保所有合約（require/ensure/invariant）都被執行。

```java
public static Sprint toDomain(SprintData data) {
    // Step 1: 使用業務建構函數（執行 require/ensure）
    Sprint sprint = new Sprint(productId, sprintId, name, goal, timebox,
            SprintState.PLANNED, ...);  // 從初始狀態開始

    // Step 2: 使用業務方法重建狀態變更（每個方法都執行合約）
    if (targetState == SprintState.STARTED) {
        sprint.start(userId);
    }

    // Step 3: 設定版本 + 清除 Events
    sprint.setVersion(data.getVersion());
    sprint.clearDomainEvents();
    return sprint;
}
```

### 兩種模式的比較

| 特性 | 合成事件模式 | 業務建構函數模式 |
|------|------------|----------------|
| 合約驗證 | ⚠️ 只有 when() 中的邏輯 | ✅ 完整 require/ensure/invariant |
| 髒資料檢測 | ⚠️ 無法檢測 | ✅ 會被合約攔截 |
| 維護成本 | 中（需維護合成邏輯） | 低（單一入口） |
| 適用條件 | 任意 Aggregate | 需要完整的狀態轉換方法 |

### 觸發此決策的問題

1. **SprintMapper** 原本使用 `Sprint.reconstitute()` 方法直接設定欄位，完全跳過合約驗證
2. 如果資料庫有髒資料（如違反 invariant 的狀態），reconstitute() 無法檢測
3. 重構 SprintMapper 時發現，業務建構函數模式需要 Aggregate 有完整的狀態轉換方法
4. **ProductMapper** 無法使用業務建構函數模式，因為 Product 建構函數固定 `state = DRAFT`，且沒有狀態轉換方法

## Decision

**根據 Aggregate 的特性選擇適當的 toDomain() 實作模式：**

### 規則 1：優先使用業務建構函數模式

當 Aggregate 具備以下條件時，**必須**使用業務建構函數模式：

- ✅ 有完整的狀態轉換方法（如 `start()`, `complete()`, `cancel()`）
- ✅ 業務建構函數可以從初始狀態開始
- ✅ 所有狀態都可以通過業務方法到達

**範例**：Sprint, Workflow, ProductBacklogItem

### 規則 2：允許使用合成事件模式

當 Aggregate 缺少以下條件時，**允許**使用合成事件模式：

- ⚠️ 缺少狀態轉換方法
- ⚠️ 業務建構函數固定初始狀態，無法重建其他狀態
- ⚠️ 狀態轉換邏輯過於複雜，難以用業務方法表達

**範例**：Product（缺少 `activate()`, `retire()` 等方法）

### 規則 3：禁止使用 reconstitute() 直接欄位賦值

**絕對禁止**使用 `reconstitute()` 或類似的方法直接設定欄位：

```java
// ❌ 禁止：跳過所有合約驗證
public static Sprint reconstitute(...) {
    Sprint sprint = new Sprint();  // 私有無參數建構函數
    sprint.id = id;
    sprint.state = state;  // 直接賦值
    return sprint;
}
```

### 規則 4：必須呼叫 clearDomainEvents()

無論使用哪種模式，`toDomain()` 最後**必須**呼叫 `clearDomainEvents()`：

```java
aggregate.setVersion(data.getVersion());
aggregate.clearDomainEvents();  // 清除重建過程產生的 Events
return aggregate;
```

## Consequences

### 正面影響

1. **髒資料檢測**：業務建構函數模式能在重建時檢測違反合約的髒資料
2. **單一入口**：狀態設定只通過 `when()` 方法，減少維護成本
3. **明確指引**：開發者知道何時該用哪種模式
4. **漸進改善**：可以逐步為 Aggregate 添加狀態轉換方法，再重構 Mapper

### 負面影響

1. **不一致性**：不同 Mapper 可能使用不同模式
2. **重構成本**：切換模式需要同時修改 Aggregate 和 Mapper
3. **複雜度**：業務建構函數模式需要仔細設計狀態重建順序

### 實作狀態

| Mapper | 模式 | 狀態 |
|--------|------|------|
| SprintMapper | 業務建構函數 | ✅ 已重構 |
| ProductMapper | 合成事件 | 保持現狀 |
| PbiMapper | 合成事件 | 保持現狀 |
| ScrumTeamMapper | 合成事件 | 保持現狀 |
| WorkflowMapper | 合成事件 | 保持現狀 |
| BoardMapper | 合成事件 | 保持現狀 |

## Related Documents

- `.ai/tech-stacks/java-ezddd-spring/pattern-rules/infrastructure/outbox-rules.md` - toDomain() 實作規範
- ADR-019: Outbox Pattern Implementation
- `src/main/java/tw/teddysoft/aiscrum/sprint/usecase/port/SprintMapper.java` - 業務建構函數模式範例
- `src/main/java/tw/teddysoft/aiscrum/product/usecase/port/ProductMapper.java` - 合成事件模式範例
