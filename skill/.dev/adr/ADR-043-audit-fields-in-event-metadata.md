# ADR-043: 審計欄位存放在 Event Metadata 而非 Entity

## Status
Accepted

## Date
2025-09-07

## Context
在實作 Outbox Pattern 時，發現 ProductData 需要 creatorId 欄位來滿足資料庫 NOT NULL 約束。這引發了一個重要的設計問題：審計資訊（如 creatorId、updaterId、createdAt、updatedAt）應該放在哪裡？

選項：
1. 在 Aggregate Entity 中加入審計欄位
2. 在 Data 類別和資料庫表中加入審計欄位
3. 只在 Domain Event 的 metadata 中記錄審計資訊

## Decision
我們決定採用選項 3：**審計資訊只存在 Domain Event 的 metadata 中**。

具體規範：
- `creatorId`、`updaterId` 等審計資訊只記錄在 Domain Event 的 metadata
- Aggregate Entity 不包含審計欄位
- Data 類別（如 ProductData）不包含審計欄位
- 資料庫表不需要審計欄位（移除 NOT NULL 約束）
- 審計資訊從 Event Store（message_store）查詢

## Rationale

### 為什麼不在 Entity 中加入審計欄位？
1. **保持領域模型的純粹性**：Product 不需要知道誰創建了它，這不是業務邏輯的一部分
2. **避免污染 Aggregate**：審計是基礎設施關注點，不應該混入領域層
3. **遵循 DDD 原則**：Aggregate 應該只包含業務不變量相關的資料

### 為什麼不在資料庫中儲存？
1. **避免資料重複**：Event Store 已經有完整的審計軌跡
2. **保持彈性**：不同的 Bounded Context 可能有不同的審計需求
3. **Event Sourcing 優勢**：Event Store 提供不可變的審計日誌

## Consequences

### Positive
- ✅ 保持 Aggregate 的純粹性和內聚性
- ✅ 審計資訊與業務邏輯完全分離
- ✅ Event Store 提供完整、不可變的審計軌跡
- ✅ 減少資料庫欄位和複雜度
- ✅ 更容易實作不同的審計策略

### Negative
- ❌ 查詢審計資訊需要從 Event Store，可能較慢
- ❌ 無法直接從資料表 JOIN 查詢創建者
- ❌ 需要額外的查詢邏輯來獲取審計資訊

## Implementation Examples

### ✅ 正確實作：在 Event Metadata 中記錄

```java
// Aggregate 建構子
public Product(ProductId id, ProductName name, String userId) {
    super();
    
    Map<String, String> metadata = new HashMap<>();
    metadata.put("creatorId", userId);
    metadata.put("createdAt", Instant.now().toString());
    metadata.put("ip", requestContext.getIpAddress());
    
    apply(new ProductEvents.ProductCreated(
        id,
        name,
        null,  // goal
        null,  // note
        null,  // extension
        ProductLifecycleState.DRAFT,
        metadata,  // 審計資訊在這裡！
        UUID.randomUUID(),
        DateProvider.now()
    ));
}

// 修改操作
public void setGoal(ProductGoalId goalId, String title, String userId) {
    Map<String, String> metadata = new HashMap<>();
    metadata.put("updaterId", userId);
    metadata.put("updatedAt", Instant.now().toString());
    
    apply(new ProductEvents.ProductGoalSet(
        this.id,
        goalId,
        title,
        metadata,
        UUID.randomUUID(),
        DateProvider.now()
    ));
}
```

### ❌ 錯誤實作：在 Entity 中加入審計欄位

```java
// 絕對不要這樣做！
public class Product extends AggregateRoot<Product, ProductId, ProductEvents> {
    private ProductId id;
    private ProductName name;
    private String creatorId;  // ❌ 錯誤！
    private String updaterId;  // ❌ 錯誤！
    private Instant createdAt; // ❌ 錯誤！
    private Instant updatedAt; // ❌ 錯誤！
}

// 也不要在 Data 類別中加入
@Entity
@Table(name = "product")
public class ProductData implements OutboxData<String> {
    @Id
    private String productId;
    private String name;
    
    @Column(name = "creatorId")  // ❌ 錯誤！
    private String creatorId;
}
```

## How to Query Audit Information

當需要查詢審計資訊時，從 Event Store 查詢：

```java
// 查詢誰創建了 Product
public String getProductCreator(ProductId productId) {
    // 從 message_store 查詢第一個 ProductCreated event
    var events = messageStore.getEvents(productId.value());
    var createdEvent = events.stream()
        .filter(e -> e.type.equals("ProductCreated"))
        .findFirst()
        .orElseThrow();
    
    return createdEvent.metadata.get("creatorId");
}

// 查詢修改歷史
public List<AuditEntry> getProductAuditLog(ProductId productId) {
    return messageStore.getEvents(productId.value()).stream()
        .map(event -> new AuditEntry(
            event.metadata.get("updaterId"),
            event.metadata.get("updatedAt"),
            event.type,
            event.data
        ))
        .collect(Collectors.toList());
}
```

## Migration Path

對於現有系統：
1. 保留現有資料庫欄位但設為 nullable
2. 新資料只寫入 Event metadata
3. 提供查詢介面同時支援兩種來源
4. 逐步遷移舊資料到 Event Store
5. 最終移除資料庫欄位

## References
- [Domain-Driven Design by Eric Evans](https://www.dddcommunity.org/)
- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)
- ADR-019: Outbox Pattern 實作規範
- ADR-031: Reactor 介面定義

## Notes
這個決策適用於所有 Aggregate，不只是 Product。所有審計資訊都應該遵循相同的模式。