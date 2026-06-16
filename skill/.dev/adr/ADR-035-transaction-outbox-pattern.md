# ADR-019: Transaction Outbox Pattern 實作策略

## 狀態
已接受 (Accepted) - **已更新為 ezapp 2.0.0 架構**

## 背景 (Context)
在事件驅動架構中，我們需要確保領域事件的可靠性和可追溯性。當 Aggregate 產生領域事件時，這些事件需要：
1. 確保不會遺失（即使系統崩潰）
2. 保持全域順序性（用於事件重播）
3. 支援事件溯源（Event Sourcing）
4. 能夠查詢特定 Aggregate 的事件歷史

## 決策 (Decision)

### ezapp 2.0.0 架構更新 (2025-11-27)

> **重要變更**: 從 ezapp 2.0.0 開始，框架提供了完整的 InMemory Outbox 實作，
> 不再需要專案自訂的 `GenericInMemoryRepository`。

### 1. Outbox Pattern 實作位置 (ezapp 2.0.0)
- **實作於**: 框架提供的 `OutboxRepository` + `InMemoryOrmClient` + `InMemoryMessageDbClient`
- **配置方式**: 透過 Spring Bean 配置組合框架類別
- **參考**: `.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/ProductInMemoryRepositoryConfig.java`

### 架構圖 (ezapp 2.0.0)
```
OutboxRepository
  └── OutboxRepositoryPeer
      └── OutboxStore
          └── EzOutboxStoreAdapter.createOutboxStore()
              └── EzOutboxClient
                  ├── InMemoryOrmClient ←── InMemoryOrmDb (Data 層)
                  └── InMemoryMessageDbClient ←── InMemoryMessageDb (Event 層)
```

---

## 歷史記錄：原始設計 (ezapp 1.0.0，已棄用)

> 以下內容為 ezapp 1.0.0 的原始設計，保留作為歷史參考。
> 新專案應使用 ezapp 2.0.0 框架提供的類別。

### ~~1. Outbox Pattern 實作位置 (已棄用)~~
- ~~**實作於**: `GenericInMemoryRepository`~~
- ~~**原因**: Repository 是儲存 Aggregate 的地方，在 save() 時同時儲存事件最自然~~

### 2. Outbox 資料結構
```java
private final Map<String, List<OutboxEntry>> outbox = new ConcurrentHashMap<>();
private final AtomicLong globalIndexCounter = new AtomicLong(0);

private static class OutboxEntry {
    final InternalDomainEvent event;
    final long globalIndex;
    final String streamName;
}
```

### 3. Stream Name 格式
- **格式**: `{AggregateType}:{AggregateId}`
- **範例**: `Product:product-001`, `Sprint:sprint-001`
- **生成方式**: 從 Aggregate 類別名稱和 ID 自動產生

### 4. 事件儲存時機
```java
public void save(T aggregate) {
    // 1. 儲存 Aggregate
    store.put((ID) aggregate.getId(), aggregate);
    
    // 2. 儲存事件到 Outbox（在發布前）
    storeEventsInOutbox(aggregate);
    
    // 3. 發布事件到 MessageBus
    publishEvents(aggregate);
    
    // 4. 清除 Aggregate 的事件
    aggregate.clearDomainEvents();
}
```

### 5. 查詢介面
```java
// 依 Stream Name 查詢
public List<InternalDomainEvent> findByStreamName(String aggregateStreamName)

// 取得所有事件（依 global index 排序）
public List<InternalDomainEvent> getAllDomainEvents()
```

## 影響 (Consequences)

### 正面影響
1. **事件不會遺失**: 事件在發布前先儲存
2. **支援事件重播**: 保留完整事件歷史
3. **全域順序性**: 使用 AtomicLong 確保順序
4. **執行緒安全**: 使用 ConcurrentHashMap 和 AtomicLong
5. **向後相容**: 不影響現有功能

### 負面影響
1. **記憶體使用增加**: 需要額外儲存所有事件
2. **InMemory 限制**: 重啟後事件會遺失（需要持久化解決方案）

## 實作細節

### Repository 修改
1. 新增 outbox 和 globalIndexCounter 欄位
2. 在 save() 方法中加入事件儲存邏輯
3. 提供查詢方法 findByStreamName() 和 getAllDomainEvents()
4. 提供工具方法如 clearOutbox()、getOutboxSize() 等

### Spring 配置調整
為了支援測試環境，將 MessageBus 和 Reactor 改為可選依賴：
```java
@Autowired(required = false)
public void setMessageBus(MessageBus<DomainEvent> messageBus)

@Autowired(required = false)
public void setNotifyPbiReactor(WhenSprintStartedNotifyProductBacklogItemReactor reactor)
```

## 未來改進
1. **持久化 Outbox**: 使用資料庫儲存 Outbox（參考 PlanData.java 範例）
2. **事件快照**: 定期建立快照減少重播時間
3. **事件壓縮**: 壓縮舊事件節省空間
4. **事件過期**: 設定事件保留策略

## 參考資料
- `.ai/tech-stacks/java-ezddd-spring/examples/persistence/PlanData.java` - OutboxData 介面實作範例
- Martin Fowler - [Transaction Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html)

## 決策日期
2025-08-19

## 參與者
- AI Assistant (Claude)
- 開發團隊