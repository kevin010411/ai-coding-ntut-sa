# Domain Layer Patterns (ezddd-java)

## Package Structure

```
[aggregate]/
├── entity/
│   ├── [Aggregate].java           # Aggregate Root
│   ├── [Aggregate]Events.java     # Domain Events (sealed interface)
│   ├── [Aggregate]Id.java         # Aggregate ID (record)
│   ├── [ValueObject].java         # Value Objects (records)
│   └── [Entity].java              # Child Entities (if any)
└── ...
```

## Aggregate Root

### Base Class

```java
// CORRECT
public class Product extends EsAggregateRoot<ProductId, ProductEvents> { }

// WRONG - these classes don't exist!
public class Product extends AggregateRoot { }
public class Product extends EventSourcedAggregateRoot { }
```

### Event Sourcing Golden Rule

**State can ONLY be set in the `when()` method!**

```java
// CORRECT: State set only in when()
public Product(ProductId productId, String name, ...) {
    super();
    requireNotNull("productId", productId);

    apply(new ProductCreated(productId, name, ...));  // → calls when()

    ensure("ID matches", () -> this.id.equals(productId));
}

// WRONG: Direct state assignment in constructor
public Product(ProductId productId, String name, ...) {
    super();
    this.id = productId;      // WRONG! Bypasses event sourcing
    this.name = name;         // WRONG!
}
```

### Event Replay Constructor (MANDATORY)

Event Sourcing Aggregate 必須有 event replay 建構子，供 `EsRepository` 從 Event Store 重建：

```java
// CORRECT: Event replay constructor — required by EsRepository (NOT by Mapper!)
public Product(List<ProductEvents> domainEvents) {
    super(domainEvents);
}
```

> 🔴 **沒有此建構子會導致 `EsRepository` 無法從 Event Store 重建 Aggregate。**
> ⚠️ **注意**: Mapper 不使用此建構子 — Mapper 只用 Business Constructor 從 data snapshot 重建。
> 詳見 `references/patterns/domain/aggregate.md` Rule 12。

### when() Event Handler Dispatch (MANDATORY)

Aggregate 必須 override `when()` 方法，使用 switch pattern-matching 分派事件到對應的 handler：

```java
@Override
protected void when(ProductEvents event) {
    switch (event) {
        case ProductEvents.ProductCreated e -> when(e);
        case ProductEvents.ProductRenamed e -> when(e);
    }
}

private void when(ProductEvents.ProductCreated event) {
    this.id = event.productId();
    this.name = event.name();
}

private void when(ProductEvents.ProductRenamed event) {
    this.name = event.newName();
}
```

> 詳見 `references/patterns/domain/aggregate.md` Rule 9。

### Contract Helper Methods (PIT Support)

```java
// CORRECT: Helper excluded from PIT mutation testing
private boolean _nameMatches(String expected) {
    return Objects.equals(this.name, expected);
}

public void rename(String newName, String userId) {
    // ...
    ensure("Name matches", () -> _nameMatches(newName));
}
```

### Nullable Field Comparison

```java
// CORRECT: Objects.equals() for null-safe comparison
ensure("Description matches", () -> Objects.equals(description, this.description));

// WRONG: if-else check (verbose and violates standards)
if (description != null) {
    ensure("Description matches", () -> this.description.equals(description));
}
```

## Value Objects

<!-- @authority: value_object_record_pattern | source: patterns/domain/value-object.md -->

> **@authority**: `value_object_record_pattern` — 完整定義見 `patterns/domain/value-object.md`

### 摘要
- `record` 型別 implementing `ValueObject`
- Compact constructor + `Objects.requireNonNull()`
- `toString()` override 回傳 raw value（serialization 必要）
- **ID 型別**：`valueOf(String)` + `valueOf(UUID)` + `create()` 三個 factory methods
- **非 ID 型別**：`valueOf(String)` + `valueOf(UUID)` 兩個 factory methods（無 `create()`）
- Validation 用 `IllegalArgumentException`，不用 Contract（`require`/`ensure`）
- Jackson `@JsonIgnore`：非資料欄位（如計算屬性、快取值）需標記 `@JsonIgnore` 避免序列化問題。詳見 `patterns/domain/value-object.md` § Jackson Serialization

## Domain Events

<!-- @authority: domain_event_mapper_key | source: patterns/domain/domain-event.md -->
<!-- @authority: mapping_type_prefix_position | source: patterns/domain/domain-event.md -->

### Sealed Interface Pattern

```java
// No permits clause (Java 17+ infers from same file)
public sealed interface ProductEvents extends InternalDomainEvent {

    ProductId productId();

    // source() returns aggregate instance ID — DRY: defined once at interface level
    @Override
    default String source() {
        return productId().value();
    }

    // MAPPING_TYPE_PREFIX — placed before event records (authority: domain-event.md Step 6.5)
    String MAPPING_TYPE_PREFIX = "ProductEvents$";

    // Event record definitions — NO per-record source() override needed
    record ProductCreated(
        ProductId productId,
        String name,
        Map<String, String> metadata,
        UUID id,
        Instant occurredOn
    ) implements ProductEvents, InternalDomainEvent.ConstructionEvent { }

    record ProductRenamed(
        ProductId productId,
        String newName,
        Map<String, String> metadata,
        UUID id,
        Instant occurredOn
    ) implements ProductEvents { }

    // Inline mapper — auto-registration (ADR-047)
    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductRenamed", ProductRenamed.class);
        return mapper;
    }
}
```

### Key Requirements

1. `sealed interface extends InternalDomainEvent` (no `permits` clause)
2. `{aggregate}Id()` method at interface level
3. `source()` default method at interface level, returning aggregate instance ID (`{aggregate}Id().value()`)
4. **No per-record `source()` override** — all records inherit from interface (DRY)
5. **No `aggregateId()` method** — removed from `InternalDomainEvent`
6. Inline `static mapper()` method with `MAPPING_TYPE_PREFIX` keys (authority: `domain-event.md`)
7. `static mapper()` method for auto-registration (ADR-047)
8. **VO Type Enforcement**: Event record fields representing Value Objects **必須**使用 VO 型別（如 `ProductId productId`），不可用原始型別（如 `String productId`）。詳見 `patterns/domain/domain-event.md` Rule 3.5

## Child Entities

### Key Rules

1. Entities have unique identity within aggregate
2. Child entities do NOT publish domain events (Aggregate Root does)
3. Package-private mutation methods (called by Aggregate's `when()`)
4. `equals()`/`hashCode()` based on ID only (not all fields)
5. Reference parent aggregate ID
6. **Field Mutability Analysis**: 決定欄位是否可變前，需分析操作語意（Create-only vs Mutable）。詳見 `patterns/domain/entity.md` § Field Mutability Analysis

## Common Mistakes

<!-- @authority: aggregate_isDeleted_no_declare | source: patterns/domain/aggregate.md -->

| Mistake | Fix |
|---------|-----|
| Direct state assignment | Use `apply(event)` → `when()` only |
| Using `this.xxx` as event params | Use constructor parameters |
| Using `Instant.now()` | Use `DateProvider.now()` |
| Missing `when()` handler | Add case in switch |
| Default record `toString()` | Override to return raw value |
| `if-else` for nullable | Use `Objects.equals()` |
| Missing soft-delete support | Add `when(DestructionEvent)` handler with `this.isDeleted = true` (use inherited field, do NOT declare own `isDeleted`) |
| Declaring `isDeleted`/`version` in subclass | `EsAggregateRoot` provides `isDeleted` and `version` as `protected` fields — subclass MUST NOT redeclare (field shadowing causes silent bugs) |

## Semantics Vocabulary（語意詞彙）

當產生或審查 Aggregate 程式碼時，必須：

1. **讀取語意定義**: 參考下方表格
2. **檢查 aggregate.yaml 的 `semantics:` 欄位**
3. **套用對應的 implications 和 lint rules**

| 標籤 | 意義 | 實作要求 |
|------|------|---------|
| `collection_reference_immutable` | 集合參考不可重指派 | 不產生替換集合的 setter |
| `value_immutable` | 欄位建立後不可變 | 不產生變更該欄位的 command/event |
| `identity` | Aggregate 身分識別 | 搭配 `value_immutable`，不產生改 ID 的 use case |
| `soft_delete_flag` | 軟刪除旗標 | 查詢/操作需尊重 isDeleted |
| `optimistic_concurrency_version` | 樂觀鎖版本 | 版本遞增規則 |

## Contract Test Judgment Rules

審查或產生 Contract Test 時，必須理解 DBC 契約的測試策略：

| 契約類型 | 縮寫 | 測試策略 |
|---------|------|---------|
| **Precondition** | PRE-N | 每個方法各自測試（每個方法的 PRE 不同） |
| **Postcondition** | POST-N | 每個方法各自測試（每個方法的 POST 不同） |
| **Getter Contract** | GC-N | 每個 getter 各自測試 |
| **Class Invariant** | INV-N | **只需測一次**（aggregate 層級共用） |

### Class Invariant 特殊規則
- uContract 框架會在**每個 public 方法入口**自動呼叫 `ensureInvariant()`
- 如果任一操作（如 `rename()`）已測試某個 INV，**其他操作不需重複測試**
- 例如：`rename_rejects_deleted_workflow()` 測試 INV-1 後，`changeNote()`、`createStage()` 等不需要再測 INV-1

```
❌ 錯誤判斷：「rename() 有測 INV-1，但 changeNote() 沒測 → GAP」
✅ 正確判斷：「INV-1 是 aggregate-level invariant，rename() 已測 → 不是 GAP」
```

### Contract Lambda Helper 規範
- 所有 `require/ensure/invariant` lambda 必須委派給 `private`、底線開頭（`_helperName`）的 helper 方法
- Helper 只封裝合約判斷並回傳 boolean，實際業務仍在原方法中執行
- `pom.xml` 的 `<excludedMethods> _*` 會讓 PIT 排除這些 helper

### 冪等性處理：ignore() 模式
- 使用 uContract 的 `ignore()` 實現冪等性操作
- `ignore()` 回傳 boolean，搭配 `if/return` 跳過方法執行

```java
// ✅ 正確：使用 ignore() 實現冪等性
public void select(SprintId sprintId, String userId) {
    require("Must be in backlog", () -> this.state == PbiState.IN_BACKLOG);
    if (ignore("Already selected - idempotent no-op", () ->
            this.state == PbiState.SELECTED && Objects.equals(this.sprintId, sprintId))) return;
    // 以下只有狀態需要改變時才執行
    ...
}

// ❌ 錯誤：缺少描述字串，語意不明確
if (this.state == PbiState.SELECTED) { return; }
```
