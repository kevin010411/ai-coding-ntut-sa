---
name: mapper-skill
description: |
  Generate Mapper Class with OutboxMapper inner class for Outbox Pattern (ADR-019).

  Triggered by:
  - code executor (Step 4.4, infrastructure sub-step)
  - Direct user request: "generate mapper for [aggregate]"

  Input: Aggregate and Data class specifications
  Output: {Aggregate}Mapper.java with OutboxMapper as inner class

  Mappers convert between domain aggregates and persistence data objects.

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Mapper Generation Skill

## Overview

This skill generates Mapper classes that convert between domain aggregates and Data objects.
The OutboxMapper is implemented as an **inner class** per ADR-019.

---

## INPUT

| Source | Path |
|--------|------|
| Domain Entity | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}.java` |
| Data Class | `src/main/java/{rootPackage}/{aggregate}/usecase/port/out/{Aggregate}Data.java` |

---

## OUTPUT

| File | Location |
|------|----------|
| Mapper Class | `src/main/java/{rootPackage}/{aggregate}/usecase/port/{Aggregate}Mapper.java` |

---

## ⛔ API SIGNATURE QUICK REFERENCE — 產生 Mapper 前必查 ⛔

```
╔══════════════════════════════════════════════════════════════════╗
║          MAPPER API SIGNATURE — MUST MEMORIZE!                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  OutboxMapper<T, E>  ← 只有 2 個型別參數！                      ║
║  ┌─────────────────────────────────────────────────┐            ║
║  │ T = AggregateRoot (e.g., Product)               │            ║
║  │ E = OutboxData    (e.g., ProductData)           │            ║
║  └─────────────────────────────────────────────────┘            ║
║                                                                  ║
║  ❌ OutboxMapper<Product, ProductId, ProductData, String>        ║
║     → 4 個型別參數 = 編譯錯誤！根本不存在這個 API！             ║
║                                                                  ║
║  ✅ OutboxMapper<Product, ProductData>                           ║
║     → 唯一正確的簽名                                            ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  DomainEventMapper API（靜態方法）:                              ║
║  ┌─────────────────────────────────────────────────┐            ║
║  │ DomainEventMapper.toData(InternalDomainEvent)   │            ║
║  │ DomainEventMapper.toDomain(DomainEventData)     │            ║
║  └─────────────────────────────────────────────────┘            ║
║                                                                  ║
║  ❌ product.mapDomainEvents()    → 不存在！                      ║
║  ❌ data.getEventType()          → 不存在！record 用 eventType() ║
║  ✅ product.getDomainEvents()    → List<XxxEvents>              ║
║  ✅ DomainEventMapper::toData    → 用於 stream map              ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  DomainEventData 是 record — accessor 無 get 前綴！             ║
║  ┌─────────────────────────────────────────────────┐            ║
║  │ ✅ data.eventType()     ❌ data.getEventType()  │            ║
║  │ ✅ data.occurredOn()    ❌ data.getOccurredOn() │            ║
║  │ ✅ data.source()        ❌ data.getSource()     │            ║
║  └─────────────────────────────────────────────────┘            ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: OutboxMapper as Inner Class (ADR-019)

> **⚠️ CRITICAL IMPORT WARNING:**
> `OutboxMapper` lives in **`tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox`** (ezddd-usecase jar).
> Do NOT confuse with `OutboxRepositoryPeer` / `OutboxStore` which are in `tw.teddysoft.ezddd.data.adapter.repository.outbox` (ezddd-data-api jar).
> ```java
> // ✅ CORRECT:
> import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxMapper;
>
> // ❌ WRONG (does not exist!):
> import tw.teddysoft.ezddd.data.adapter.repository.outbox.OutboxMapper;
> ```

```java
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxMapper;

// ✅ CORRECT: Standalone OutboxMapper class
public class ProductMapper implements OutboxMapper<Product, ProductData> {

    @Override
    public Product toDomain(ProductData data) { ... }

    @Override
    public ProductData toData(Product aggregateRoot) { ... }
}

// ❌ WRONG: OutboxMapper has only 2 type parameters, NOT 4!
// OutboxMapper<Product, ProductId, ProductData, String>  ← DOES NOT EXIST!
// The correct signature is always: OutboxMapper<AggregateRoot, Data>
```

**Rationale:** Standalone implementation is simpler and sufficient. The Mapper class directly implements `OutboxMapper<AggregateRoot, Data>`.

### Rule 2: toDomain() — Business Constructor + Command Methods + clearDomainEvents()

> **⚠️ CRITICAL**: Mapper 的 `toDomain()` 從 data snapshot 重建 aggregate。
> **Mapper 不處理 Event Sourcing** — Event replay 是 `EsRepository` 的職責。
> EsRepository 使用 event replay constructor（如 `public Product(List<ProductEvents> domainEvents)`）重建 aggregate，
> 而 Mapper 使用 **Business Constructor**。不需要 `hasCreationEvent` 判斷，不需要 `new Aggregate(domainEvents)` 分支。
>
> **✅ 正確模式（cross-ref: critical-rules Rule 24）**: toDomain() 使用 **Business Constructor**
> 建立 aggregate，再用 **command methods** 重建 post-creation 狀態（集合、欄位等）。
> Command methods 會產生 phantom events，因此 **必須** 在最後先呼叫
> `setVersion(data.getVersion())` 還原版本，再呼叫 `clearDomainEvents()` 丟棄這些事件。

```java
// ✅ CORRECT: Business Constructor + command methods + clearDomainEvents()
public static Board toDomain(BoardData data) {
    Objects.requireNonNull(data, "BoardData cannot be null");

    // ① Business Constructor（creation-time fields）
    Board board = new Board(
            data.getTeamId(),
            BoardId.valueOf(data.getBoardId()),
            data.getName());

    // ② Command methods 重建 post-creation 狀態
    // 集合：iterate Data 集合，逐一呼叫 command method 重建
    for (BoardMemberData memberData : data.getBoardMemberDatas()) {
        BoardRole boardRole = BoardRole.valueOf(memberData.getRole());
        board.joinAs(boardRole, memberData.getUserId());
    }

    for (BoardSessionData sessionData : data.getBoardSessionDatas()) {
        BoardSession session = BoardSessionMapper.toDomain(sessionData);
        board.acceptUserEntry(session.boardSessionId(), session.userId());
    }

    // 簡單欄位：呼叫 command method 重建
    board.changeNote(data.getNote());

    // ③ Version + clearDomainEvents()（⛔ 永遠是最後兩行！）
    board.setVersion(data.getVersion());
    board.clearDomainEvents();  // 丟棄 command methods 產生的 phantom events
    return board;
}

// ❌ FORBIDDEN: Event Sourcing branch in Mapper — this is EsRepository's job!
if (data.getDomainEventDatas() != null && !data.getDomainEventDatas().isEmpty()) {
    var domainEvents = ...;
    Sprint aggregate = new Sprint(domainEvents);  // WRONG in Mapper!
}

// ❌ FORBIDDEN: Synthesized Events — only executes when(), skips require/ensure/invariant
ProductEvents.ProductCreated syntheticEvent = new ProductEvents.ProductCreated(/* from data */);
Product product = new Product(List.of(syntheticEvent));

// ❌ FORBIDDEN: reconstitute() — skips ALL contract validation
public static Product toDomain(ProductData data) {
    return Product.reconstitute(ProductId.valueOf(data.getId()), data.getName());
}
```

**Rationale:**
- Mapper 只做 data snapshot ↔ domain 的轉換，不做 event replay
- Business Constructor 執行 require/ensure/invariant contracts，可偵測髒資料
- Command methods 走過真正的業務邏輯路徑，確保重建狀態的正確性
- `clearDomainEvents()` 丟棄 command methods 產生的 phantom events，防止被重複發布
- `setVersion(data.getVersion())` 還原版本號（必須在 clearDomainEvents 之前）
- Synthesized Events pattern **禁止** — 只執行 `when()` 邏輯，跳過 contract 驗證

### Rule 3: toData() - Map All Fields

> **🚨 CRITICAL WARNING: EzOutboxClient.save() Silent Skip Behavior**
>
> `EzOutboxClient.save()` checks `data.getDomainEventDatas()` internally.
> **If `domainEventDatas` is empty or null, it silently skips the entire ORM save operation** —
> no exception, no log, no warning. The aggregate simply won't be persisted.
>
> This means `toData()` **MUST** call `DomainEventMapper.toData(events)` to populate
> `domainEventDatas`. Missing this call causes:
> - ✅ InMemory profile: tests pass (InMemory doesn't check events)
> - ❌ Outbox profile: **data silently lost** — no persistence, no error
>
> ```java
> // ✅ MANDATORY in every toData():
> data.setDomainEventDatas(
>     aggregate.getDomainEvents().stream()
>         .map(DomainEventMapper::toData)
>         .collect(Collectors.toList())
> );
>
> // ❌ MISSING THIS = SILENT DATA LOSS IN OUTBOX PROFILE
> ```

```java
// ✅ CORRECT: Map all fields from domain to data
public static ProductData toData(Product product) {
    Objects.requireNonNull(product, "Product cannot be null");

    ProductData data = new ProductData(product.getVersion());
    data.setId(product.getId().toString());
    data.setName(product.getName().toString());
    data.setDeleted(product.isDeleted());
    data.setCreatedAt(extractCreatedAt(product));
    data.setLastUpdated(extractLastUpdated(product));
    data.setStreamName(product.getStreamName());
    data.setDomainEventDatas(
        product.getDomainEvents().stream()
            .map(DomainEventMapper::toData)
            .collect(Collectors.toList())
    );

    return data;
}

private static Instant extractCreatedAt(Product product) {
    if (!product.getDomainEvents().isEmpty()) {
        return product.getDomainEvents().get(0).occurredOn();
    }
    return DateProvider.now();
}
```

### Rule 4: Handle Child Entities / Collections in toData() — JSON Serialization

> **原則**: Aggregate 內部物件一律存在同一張 table（見 persistent-object.md Rule 11）。
> 集合和複雜物件用 JSON 字串序列化。

```java
// ✅ CORRECT: 集合序列化為 JSON 字串存在同一 table
public static ProductData toData(Product product) {
    ProductData data = new ProductData(product.getVersion());
    // ... map basic fields

    // 簡單 VO：展開為多個 column
    if (product.getGoal() != null) {
        data.setGoalTitle(product.getGoal().title());
        data.setGoalDescription(product.getGoal().description());
        data.setGoalState(product.getGoal().state().name());
    }

    // 集合：序列化為 JSON 字串
    data.setGoalMetricsJson(objectMapper.writeValueAsString(product.getGoalMetrics()));
    data.setCommittedSprintIdsJson(objectMapper.writeValueAsString(
            product.getCommittedSprintIds().stream()
                    .map(SprintId::value)
                    .collect(Collectors.toList())));

    // ... domainEventDatas, streamName, version
    return data;
}

// ❌ WRONG: 使用 OneToMany 子表
data.getProjectDatas().add(ProjectMapper.toData(project));  // 建立獨立子表！
```

### Rule 5: Handle Child Entities / Collections in toDomain() — Command Methods

> 使用 **command methods** 重建子 Entity/集合（如 Board 的 `joinAs()`、`acceptUserEntry()`）。
> 集合元素逐一透過 command method 加入，`clearDomainEvents()` 在最後丟棄 phantom events。
> 參見 Rule 2 的 Board 範例。

```java
// ✅ CORRECT: Business Constructor + command methods 重建集合
public static Product toDomain(ProductData data) {
    Objects.requireNonNull(data, "ProductData cannot be null");

    // ① Business Constructor (creation-time fields only)
    Product product = new Product(
            ProductId.valueOf(data.getId()),
            data.getName(),
            data.getUserId());

    // ② 簡單欄位/VO：呼叫 command method 重建
    if (data.getGoalTitle() != null) {
        product.setGoal(data.getGoalTitle(), data.getGoalDescription(), data.getUserId());
    }

    // ③ 集合：iterate Data 集合，逐一呼叫 command method 重建
    for (String sprintId : deserializeSprintIds(data.getCommittedSprintIdsJson())) {
        product.commitSprint(SprintId.valueOf(sprintId), data.getUserId());
    }

    // ④ Boolean Flags / 狀態
    if (data.isDeleted()) {
        product.delete(data.getUserId());
    }

    // ⑤ Version + clearDomainEvents()（⛔ 永遠是最後兩行！）
    product.setVersion(data.getVersion());
    product.clearDomainEvents();  // 丟棄 command methods 產生的 phantom events
    return product;
}
```

### Rule 6: toReadOnly() Methods (Optional)

Query outputs should use read-only entities, not DTO records. If a mapper helper is needed for read-side conversion, name it `toReadOnly(...)` and return `readonly*` proxies.

```java
// ✅ CORRECT: wrap a domain object with a read-only proxy
public static readonlyProduct toReadOnly(Product product) {
    return new readonlyProduct(product);
}

// ✅ CORRECT: infrastructure data is converted to domain first, then wrapped
public static readonlyProduct toReadOnly(ProductData data) {
    return new readonlyProduct(toDomain(data));
}

public static List<readonlyProduct> toReadOnly(List<ProductData> dataList) {
    return dataList.stream()
        .map(ProductMapper::toReadOnly)
        .toList();
}
```

### Rule 7: Null Checks at Entry Points

> Mapper 是基礎設施層，null check 統一使用 `Objects.requireNonNull()`（簡單 null check，非 DBC）。
> `Contract.requireNotNull()` 保留給 Aggregate Root 和 UseCase Service execute()。

```java
// ✅ CORRECT: Objects.requireNonNull at entry — Mapper is infrastructure, not DBC
public static ProductData toData(Product product) {
    Objects.requireNonNull(product, "Product cannot be null");
    // ...
}

public static Product toDomain(ProductData data) {
    Objects.requireNonNull(data, "ProductData cannot be null");
    // ...
}

// ❌ WRONG: No null check
public static Product toDomain(ProductData data) {
    var events = data.getDomainEventDatas()...  // NPE if data is null!
}
```

### Rule 8: Complex Object Serialization

```java
// For complex objects stored as JSON strings
private static String serializeGoal(SprintGoal goal) {
    if (goal == null) return null;
    return objectMapper.writeValueAsString(goal);
}

private static SprintGoal deserializeGoal(String json) {
    if (json == null || json.isBlank()) return null;
    return objectMapper.readValue(json, SprintGoal.class);
}
```

### Rule 9: State Reconstruction Order

```java
// ✅ CORRECT: Business Constructor + command methods 重建狀態
public static Sprint toDomain(SprintData data) {
    // 1. Create with Business Constructor
    Sprint sprint = new Sprint(...);

    // 2. 用 command methods 重建 post-creation 狀態
    sprint.changeNote(data.getNote());
    // ... 其他 command methods ...

    // 3. Version + clearDomainEvents()（永遠是最後兩行）
    sprint.setVersion(data.getVersion());
    sprint.clearDomainEvents();  // 丟棄 phantom events
    return sprint;
}
```

### Rule 9.5: State Reconstruction Checklist ⭐⭐⭐ CRITICAL

> **⚠️ CRITICAL**: `toDomain()` 必須還原 Aggregate 的**所有可變狀態**。
> 遺漏任何一類狀態會導致 Outbox Profile 下 save/load cycle 後狀態不正確。
> 這是 Outbox 測試失敗的最常見原因（Issue #9, #11, #13 反覆出現）。

**必須依序還原的 4 類狀態（使用 Business Constructor + command methods）：**

```
╔══════════════════════════════════════════════════════════════════╗
║     toDomain() STATE RECONSTRUCTION CHECKLIST (Rule 2 Pattern)     ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ① 基本欄位 (Basic Fields)                                       ║
║     → 透過 Business Constructor 參數傳入                          ║
║     → 例: name, creatorId                                       ║
║                                                                  ║
║  ② 集合 / 子實體 / Post-Creation 狀態                            ║
║     → 使用 command methods 重建                                  ║
║     → 例: board.joinAs(role, userId)                             ║
║     → 例: board.acceptUserEntry(sessionId, userId)               ║
║     → 例: product.commitSprint(sprintId, userId)                 ║
║     → 例: board.changeNote(data.getNote())                       ║
║                                                                  ║
║  ③ Boolean Flags / 刪除 (如 isDeleted) ⚠️ 最容易遺漏！           ║
║     → 使用 command method 還原                                   ║
║     → 例: aggregate.delete(userId)                               ║
║                                                                  ║
║  ④ setVersion() → clearDomainEvents() — ⛔ 永遠是最後兩行，順序不可反！ ║
║     → aggregate.setVersion(data.getVersion());                   ║
║     → aggregate.clearDomainEvents();  // 丟棄 phantom events     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

```java
// ✅ CORRECT: Business Constructor + command methods 還原所有狀態
public static Board toDomain(BoardData data) {
    Objects.requireNonNull(data, "BoardData cannot be null");

    // ① 基本欄位 — Business Constructor
    Board board = new Board(
            data.getTeamId(),
            BoardId.valueOf(data.getBoardId()),
            data.getName());

    // ② 集合 — iterate + command methods
    for (BoardMemberData memberData : data.getBoardMemberDatas()) {
        BoardRole boardRole = BoardRole.valueOf(memberData.getRole());
        board.joinAs(boardRole, memberData.getUserId());
    }
    for (BoardSessionData sessionData : data.getBoardSessionDatas()) {
        BoardSession session = BoardSessionMapper.toDomain(sessionData);
        board.acceptUserEntry(session.boardSessionId(), session.userId());
    }

    // 簡單欄位 — command method
    board.changeNote(data.getNote());

    // ③ Boolean Flags
    // if (data.isDeleted()) { board.delete(userId); }

    // ④ Version + clearDomainEvents()（⛔ 永遠是最後兩行！）
    board.setVersion(data.getVersion());
    board.clearDomainEvents();  // 丟棄 command methods 產生的 phantom events
    return board;
}

// ❌ WRONG: 遺漏集合還原 — Aggregate 重建後少了子實體
Board board = new Board(...);
// 沒有 for (BoardMemberData ...) { board.joinAs(...); }  ← BUG!
board.setVersion(data.getVersion());
board.clearDomainEvents();
return board;
```

### Rule 9.6: toDomain() 重建原則 ⭐⭐⭐

> **✅ 正確模式（cross-ref: critical-rules Rule 24）**: toDomain() 使用 **Business Constructor +
> command methods** 重建狀態，最後呼叫 `setVersion()` + `clearDomainEvents()` 收尾（順序不可反！見 Rule 9.5）。
> Command methods 會產生 phantom events，`clearDomainEvents()` 負責丟棄它們。

```java
// ✅ 在 toDomain() 中呼叫 command methods 重建 post-creation 狀態
board.joinAs(boardRole, memberData.getUserId());    // 重建集合
board.acceptUserEntry(sessionId, userId);           // 重建集合
board.changeNote(data.getNote());                   // 重建簡單欄位

// ⛔ 永遠以這兩行收尾
board.setVersion(data.getVersion());
board.clearDomainEvents();  // 丟棄所有 phantom events
```

**重點**：command methods 產生的 events 由 `clearDomainEvents()` 統一丟棄，
因此不需要額外的 `*ForReconstruction` setter 來繞過 event 產生。

### Rule 9.7: Child Entity Reconstruction Strategy Selection ⭐⭐⭐ CRITICAL

> **ROOT CAUSE (Workflow CBF Failure F3)**: Rule 5 的「command methods 重建」模式有一個**隱含前提**：
> domain command methods 的 precondition 不依賴同集合中其他元素的存在性。
> 當子實體有遞迴樹狀結構時（如 Workflow 的 Lane tree），使用 command methods 重建會失敗，
> 因為 child Lane 的 parent 可能尚未被加入。

**策略選擇表**:

| 子實體特徵 | 重建策略 | 原因 | 範例 |
|-----------|---------|------|------|
| 扁平集合，precondition 不依賴同集合元素 | **Command methods** (Rule 5) | 走完整業務路徑，`clearDomainEvents()` 丟棄 phantom events | `board.joinAs(role, userId)` |
| 遞迴樹狀結構，precondition 驗證 parent 存在 | **Direct population** | 避免 precondition 失敗和 phantom events | `workflow.getRootStages().addAll(lanes)` |
| 子實體 command method 會 apply event 並改變 version | **Direct population** | 避免 version drift 和 phantom events | 同上 |

**Direct Population 模式**:

```java
// ✅ CORRECT: Direct population for recursive tree structures
// Bypass DBC contracts to avoid precondition failures and phantom events
List<Lane> lanes = deserializeLanes(data.getRootStagesJson(), workflowId);
workflow.getRootStages().addAll(lanes);  // Direct list population

// Then continue with normal cleanup:
workflow.setVersion(data.getVersion());
workflow.clearDomainEvents();

// ❌ WRONG: Using domain command methods for tree reconstruction
// createStage() validates parent exists → fails when parent not yet added
workflow.createStage(parentId, stageId, name, wipLimit, laneType, userId);
// Also generates phantom events AND increments version!
```

**決策流程圖**:
```
aggregate 有子實體？
  ├─ 否 → 不需要重建子實體
  └─ 是 → 子實體是遞迴樹狀結構？
       ├─ 否 → 子實體 command method 有 precondition 依賴同集合？
       │    ├─ 否 → 使用 Command methods (Rule 5)
       │    └─ 是 → 使用 Direct population
       └─ 是 → 使用 Direct population
```

**JSON 序列化/反序列化配套（必須同步實作）**:

```java
// toData() 中：
data.setRootStagesJson(serializeLanes(aggregate.getRootStages()));

// toDomain() 中：
List<Lane> lanes = deserializeLanes(data.getRootStagesJson(), workflowId);
aggregate.getRootStages().addAll(lanes);
```

**注意**: Direct population 不會產生 domain events，因此不影響 `clearDomainEvents()` 的效果。
但必須確保 `setVersion()` 正確還原版本號。

### Rule 10: Package Location

```java
// ✅ CORRECT: Mapper in usecase/port/
package tw.teddysoft.aiscrum.product.usecase.port;

public class ProductMapper { }

// ❌ WRONG: Mapper in adapter layer
package tw.teddysoft.aiscrum.product.adapter.out.repository;
```

### Rule 11: Sync Mapper When New Aggregate Behaviors Are Added

> **⚠️ CRITICAL**: 每當新增 Aggregate 行為（新的 Command/Event），`toData()` 和 `toDomain()` 都必須同步更新。
> 忘記更新 Mapper 是 Outbox Profile 測試失敗的最常見原因之一。

**同步檢查清單：**

```
新增行為後，依序檢查：
1. ✅ Data class 有對應的新欄位？      → 見 persistent-object.md Rule 11
2. ✅ toData() 寫入新欄位？            → data.setGoalTitle(aggregate.getGoal().title())
3. ✅ toDomain() 重建新狀態？            → aggregate.setGoal(...)
4. ✅ toReadOnly() 包含新欄位？        → 如果 Query read model 需要
```

```java
// ✅ CORRECT: toData() handles new behavior's state (同一 table，JSON for collections)
public static ProductData toData(Product product) {
    // ... existing fields ...

    // NEW: Added when setGoal() behavior was introduced (簡單 VO → column)
    if (product.getGoal() != null) {
        data.setGoalTitle(product.getGoal().title());
        data.setGoalDescription(product.getGoal().description());
        data.setGoalState(product.getGoal().state().name());
    }

    // NEW: Added when addGoalMetric() behavior was introduced (集合 → JSON column)
    data.setGoalMetricsJson(objectMapper.writeValueAsString(product.getGoalMetrics()));

    // NEW: Added when commitSprint() behavior was introduced (ID 集合 → JSON column)
    data.setCommittedSprintIdsJson(objectMapper.writeValueAsString(
            product.getCommittedSprintIds().stream()
                    .map(SprintId::value).collect(Collectors.toList())));

    return data;
}

// ✅ CORRECT: toDomain() 使用 command methods 重建新行為的狀態
Product product = new Product(ProductId.valueOf(data.getId()), data.getName(), ...);

// 簡單欄位/VO：command method 重建
if (data.getGoalTitle() != null) {
    product.setGoal(data.getGoalTitle(), data.getGoalDescription(), data.getUserId());
}
// 集合：iterate + command method 重建
for (String sprintId : deserializeSprintIds(data.getCommittedSprintIdsJson())) {
    product.commitSprint(SprintId.valueOf(sprintId), data.getUserId());
}
if (data.isDeleted()) {
    product.delete(data.getUserId());
}

product.setVersion(data.getVersion());
product.clearDomainEvents();  // 丟棄 phantom events
return product;
```

**Symptom**: InMemory 測試全過，Outbox 測試在 save/load cycle 後新狀態為 null。

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Verification |
|-------|--------------|
| Domain entity exists | {Aggregate}.java exists |
| Data class exists | {Aggregate}Data.java exists |
| Events class exists | {Aggregate}Events.java exists |

### Checkpoint 2: Post-Generation

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify inner class pattern
grep "static class Mapper implements OutboxMapper" ${mapperFile}

# Verify newMapper() method
grep "public static OutboxMapper.*newMapper()" ${mapperFile}

# Verify clearDomainEvents() call
grep "clearDomainEvents()" ${mapperFile}
```

---

## GENERATION TEMPLATES

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port;

import ${rootPackage}.common.entity.DateProvider;
import ${rootPackage}.${aggregateLowerCase}.entity.${Aggregate};
import ${rootPackage}.${aggregateLowerCase}.entity.${Aggregate}Events;
import ${rootPackage}.${aggregateLowerCase}.entity.${Aggregate}Id;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.out.${Aggregate}Data;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxMapper;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;

public class ${Aggregate}Mapper {

    // OutboxMapper instance
    private static OutboxMapper<${Aggregate}, ${Aggregate}Data> mapper = new ${Aggregate}Mapper.Mapper();

    public static OutboxMapper<${Aggregate}, ${Aggregate}Data> newMapper() {
        return mapper;
    }

    // Domain -> Data
    public static ${Aggregate}Data toData(${Aggregate} aggregate) {
        Objects.requireNonNull(aggregate, "${Aggregate} cannot be null");

        ${Aggregate}Data data = new ${Aggregate}Data(aggregate.getVersion());
        data.setId(aggregate.getId().toString());
        // Map all fields...
        data.setDeleted(aggregate.isDeleted());
        data.setCreatedAt(extractCreatedAt(aggregate));
        data.setLastUpdated(extractLastUpdated(aggregate));
        data.setStreamName(aggregate.getStreamName());
        data.setDomainEventDatas(
            aggregate.getDomainEvents().stream()
                .map(DomainEventMapper::toData)
                .collect(Collectors.toList())
        );

        return data;
    }

    // Data -> Domain (Business Constructor + Command Methods — Rule 2)
    public static ${Aggregate} toDomain(${Aggregate}Data data) {
        Objects.requireNonNull(data, "${Aggregate}Data cannot be null");

        // ① 基本欄位 — Business Constructor
        ${Aggregate} aggregate = new ${Aggregate}(
                ${Aggregate}Id.valueOf(data.getId()),
                // TODO: Map all required constructor parameters from data
        );

        // ② Post-creation 狀態 — command methods
        // TODO: 集合用 for-loop + command method 重建
        // for (XxxData xxxData : data.getXxxDatas()) {
        //     aggregate.addXxx(xxxData.getField1(), xxxData.getField2());
        // }
        // TODO: 簡單欄位用 command method 重建
        // aggregate.changeNote(data.getNote());

        // ③ Boolean Flags（如 isDeleted）⚠️ 最容易遺漏！
        // TODO: if (data.isDeleted()) { aggregate.delete(userId); }

        // ④ Version + clearDomainEvents()（⛔ 永遠是最後兩行！）
        aggregate.setVersion(data.getVersion());
        aggregate.clearDomainEvents();  // 丟棄 command methods 產生的 phantom events
        return aggregate;
    }

    // Data -> read-only entity
    public static ${Aggregate}ReadOnly toReadOnly(${Aggregate}Data data) {
        Objects.requireNonNull(data, "${Aggregate}Data cannot be null");
        return ${Aggregate}ReadOnly.from(
            data.getId(),
            // Map fields to read-only entity...
        );
    }

    public static List<${Aggregate}ReadOnly> toReadOnly(List<${Aggregate}Data> dataList) {
        return dataList.stream()
            .map(${Aggregate}Mapper::toReadOnly)
            .toList();
    }

    // Helper methods
    private static Instant extractCreatedAt(${Aggregate} aggregate) {
        if (!aggregate.getDomainEvents().isEmpty()) {
            return aggregate.getDomainEvents().get(0).occurredOn();
        }
        return DateProvider.now();
    }

    private static Instant extractLastUpdated(${Aggregate} aggregate) {
        if (!aggregate.getDomainEvents().isEmpty()) {
            return aggregate.getDomainEvents()
                .get(aggregate.getDomainEvents().size() - 1).occurredOn();
        }
        return DateProvider.now();
    }

    // OutboxMapper inner class (ADR-019)
    static class Mapper implements OutboxMapper<${Aggregate}, ${Aggregate}Data> {

        @Override
        public ${Aggregate} toDomain(${Aggregate}Data data) {
            return ${Aggregate}Mapper.toDomain(data);
        }

        @Override
        public ${Aggregate}Data toData(${Aggregate} aggregateRoot) {
            return ${Aggregate}Mapper.toData(aggregateRoot);
        }
    }
}
```

---

<!-- @authority: dateprovider_not_instant | source: rules/common-rules.md -->

## EXAMPLE OUTPUT

### SprintMapper.java（SprintMapper Pattern 範例）

> 所有新產生的 Mapper 必須遵循此模式。

```java
package tw.teddysoft.aiscrum.sprint.usecase.port;

import tw.teddysoft.aiscrum.common.entity.DateProvider;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.sprint.entity.*;
import tw.teddysoft.aiscrum.sprint.usecase.port.out.SprintData;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxMapper;

import java.time.Instant;
import java.time.ZoneId;
import java.util.stream.Collectors;

import java.util.Objects;

public class SprintMapper {

    private static final OutboxMapper<Sprint, SprintData> mapper = new Mapper();

    public static OutboxMapper<Sprint, SprintData> newMapper() {
        return mapper;
    }

    public static SprintData toData(Sprint aggregate) {
        Objects.requireNonNull(aggregate, "Sprint cannot be null");

        SprintData data = new SprintData(aggregate.getVersion());
        data.setSprintId(aggregate.getId().value());
        data.setProductId(aggregate.getProductId().value());
        data.setName(aggregate.getName().value());
        data.setDeleted(aggregate.isDeleted());
        data.setState(aggregate.getState().name());
        data.setStartDateTime(aggregate.getTimebox().start());
        data.setEndDateTime(aggregate.getTimebox().end());
        data.setZoneId(aggregate.getTimebox().zoneId().getId());
        data.setGoal(aggregate.getGoal() != null ? aggregate.getGoal().value() : null);
        data.setNote(aggregate.getNote());
        data.setCreatorId(aggregate.getCreatorId());

        Instant createdAt = aggregate.getDomainEvents().stream()
                .filter(e -> e instanceof SprintEvents.SprintCreated)
                .map(e -> ((SprintEvents.SprintCreated) e).occurredOn())
                .findFirst()
                .orElse(DateProvider.now());
        data.setCreatedAt(createdAt);

        data.setStreamName(aggregate.getStreamName());
        data.setDomainEventDatas(
                aggregate.getDomainEvents().stream()
                        .map(DomainEventMapper::toData)
                        .collect(Collectors.toList())
        );

        return data;
    }

    public static Sprint toDomain(SprintData data) {
        Objects.requireNonNull(data, "SprintData cannot be null");

        // ① Business Constructor
        Sprint sprint = new Sprint(
                ProductId.valueOf(data.getProductId()),
                SprintId.valueOf(data.getSprintId()),
                SprintName.valueOf(data.getName()),
                data.getGoal() != null ? SprintGoal.valueOf(data.getGoal()) : null,
                Timebox.of(data.getStartDateTime(), data.getEndDateTime(),
                        ZoneId.of(data.getZoneId())),
                data.getNote(),
                data.getCreatorId()
        );

        // ② Command methods 重建 post-creation 狀態
        // sprint.changeNote(data.getNote());
        // ... 其他 command methods 重建集合或欄位 ...

        // ③ Version + clearDomainEvents()（⛔ 永遠是最後兩行！）
        sprint.setVersion(data.getVersion());
        sprint.clearDomainEvents();  // 丟棄 phantom events
        return sprint;
    }

    public static SprintReadOnly toReadOnly(SprintData data) {
        Objects.requireNonNull(data, "SprintData cannot be null");
        // ... map data to SprintReadOnly
    }

    static class Mapper implements OutboxMapper<Sprint, SprintData> {
        @Override
        public Sprint toDomain(SprintData data) {
            return SprintMapper.toDomain(data);
        }

        @Override
        public SprintData toData(Sprint aggregateRoot) {
            return SprintMapper.toData(aggregateRoot);
        }
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.5: Invoke mapper-skill
    ├─ Input: {Aggregate}.java, {Aggregate}Data.java
    ├─ Output: {Aggregate}Mapper.java
    └─ Next: config-skill (Step 4.6)
```

---

## OUTBOX INFRASTRUCTURE WARNING

### @NoRepositoryBean Trap — PgMessageDbClient

> **⚠️ WARNING**: The framework class `PgMessageDbClient` is annotated with `@NoRepositoryBean`.
> Spring's auto-scan (`@EnableJpaRepositories`) CANNOT auto-discover `@NoRepositoryBean` interfaces.
>
> **Project standard (authority: outbox.md Rule 7)**: Use `EntityManager` + `JpaRepositoryFactory` to
> programmatically create a proxy. No sub-interface needed.

```java
// ✅ CORRECT (project standard): JpaRepositoryFactory creates proxy directly
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;

@Configuration
@Profile({"outbox", "test-outbox"})
public class SharedOutboxConfig {

    @PersistenceContext
    private EntityManager entityManager;

    @Bean
    public PgMessageDbClient pgMessageDbClient() {
        RepositoryFactorySupport factory = new JpaRepositoryFactory(entityManager);
        return factory.getRepository(PgMessageDbClient.class);
    }
}
```

```java
// ❌ WRONG: Directly injecting PgMessageDbClient without JpaRepositoryFactory
@Autowired
private PgMessageDbClient pgMessageDbClient;
// Error: @NoRepositoryBean prevents Spring auto-scan from creating proxy
```

**Symptom**: `NoSuchBeanDefinitionException` for `PgMessageDbClient` at runtime under Outbox profile.

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Missing clearDomainEvents() | Add at end of toDomain() |
| Standalone OutboxMapper | Convert to inner class pattern |
| reconstitute() usage | Replace with business constructor |
| UnsupportedOperationException in else | Use Business Constructor pattern |
| Boolean flag (isDeleted) not restored after save/load | toDomain() 遺漏 ⑤ Boolean Flags 步驟。加入 `if (data.isDeleted()) { aggregate.delete(...); }` 在 version 設定之前（見 Rule 9.5） |
| Precondition check bypassed for deleted aggregate | 同上 — isDeleted 未還原導致 soft-delete guard 失效 |

---
