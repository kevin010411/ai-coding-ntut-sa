---
name: domain-event-skill
description: |
  Generate Domain Events following Event Sourcing patterns with ezddd framework.

  Triggered by:
  - code executor (Step 4.1.1, after aggregate-skill)
  - Direct user request: "generate events for [Aggregate]"

  Input: aggregate.yaml specification (domain_events section)
  Output: [Aggregate]Events.java file

  This skill embeds critical Domain Event rules to ensure:
  - Proper sealed interface structure
  - Inline mapper for Event Store serialization
  - Auto-registration support (ADR-047)

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Domain Event Generation Skill

## Overview

This skill generates Domain Events as a sealed interface containing multiple event records.
All events for one aggregate are defined in a single `{Aggregate}Events.java` file.

---

## INPUT

| Source | Path |
|--------|------|
| Aggregate Spec | `JSON spec `aggregates[]`` |
| Domain Events Section | `aggregate.yaml → domain_events` |

---

## OUTPUT

| File | Location |
|------|----------|
| Domain Events | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}Events.java` |

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Sealed Interface Declaration (No permits clause)

```java
// ✅ CORRECT: Sealed interface WITHOUT permits clause
// (Records in same file are automatically permitted by Java compiler)
public sealed interface ProductEvents extends InternalDomainEvent {
    // ...
}

// ❌ WRONG: Explicit permits clause (unnecessary, verbose)
public sealed interface ProductEvents extends InternalDomainEvent permits
        ProductEvents.ProductCreated,
        ProductEvents.ProductRenamed,
        ProductEvents.ProductDeleted {
    // ...
}

// ❌ WRONG: Non-sealed interface
public interface ProductEvents extends InternalDomainEvent {
    // Missing sealed keyword
}

// ❌ WRONG: Wrong base interface
public sealed interface ProductEvents extends DomainEvent {
    // Use InternalDomainEvent, not DomainEvent
}
```

**Rationale:** Java 17+ allows omitting `permits` when all subtypes are in the same file. This is cleaner and avoids maintenance burden when adding new events.

### Rule 2: Aggregate ID Method at Interface Level

```java
// ✅ CORRECT: Define at interface level, all events inherit
public sealed interface ProductEvents extends InternalDomainEvent {

    ProductId productId();  // Every event must provide aggregate ID

    // ...
}

// ❌ WRONG: Define in each event record separately
record ProductCreated(ProductId productId, ...) {
    public ProductId productId() { return productId; }  // Redundant if in interface
}
```

### Rule 3: source() Default Method at Interface Level (DRY)

```java
// ✅ CORRECT: source() at interface level, returns aggregate instance ID
public sealed interface ProductEvents extends InternalDomainEvent {

    ProductId productId();

    // source() returns the aggregate instance ID as string
    @Override
    default String source() {
        return productId().value();
    }

    record ProductCreated(...) implements ProductEvents, InternalDomainEvent.ConstructionEvent {
        // NO source() override needed — inherits from interface
        // ...
    }

    record ProductRenamed(...) implements ProductEvents {
        // NO source() override needed — inherits from interface
        // ...
    }
}

// ❌ WRONG: Per-record source() override (violates DRY)
public sealed interface ProductEvents extends InternalDomainEvent {
    record ProductCreated(...) implements ProductEvents {
        @Override
        public String source() {
            return "Product";  // WRONG! Don't override per-record, use default method
        }
    }
}

// ❌ WRONG: aggregateId() method (no longer exists in InternalDomainEvent)
public sealed interface ProductEvents extends InternalDomainEvent {
    default String aggregateId() {
        return productId().value();  // WRONG! aggregateId() has been removed from framework
    }
}

// ❌ WRONG: Missing source() default method
// Framework cannot identify which aggregate instance the event belongs to
```

**Rationale:**
- `source()` returns the aggregate **instance ID** (e.g., `"550e8400-..."`) — used for stream identification and event routing
- `InternalDomainEvent` no longer has `aggregateId()` — `source()` is the only identification method
- DRY principle: define `source()` once at sealed interface level, all event records automatically inherit
- Each record does NOT need to override `source()` — the default method handles it

### Rule 3.5: VO Type Mapping — Aggregate Attributes vs Event Record Fields

> **⛔ MANDATORY RULE**: 如果 Aggregate 已定義 VO（如 `BoardId`, `TeamId`, `ProductName`），
> Event Record **必須使用該 VO 型別**，**禁止退化為 String**。
> 唯一例外是 **Enum 必須降級為 String**
> （Enum 是封閉集合，成員可能增刪改名，直接儲存會導致歷史事件反序列化失敗）。

**核心原則：Aggregate 有 VO，Event 就用 VO。**

**映射規則表：**

| aggregate.yaml 型別 | Aggregate 內部欄位 | Event Record 欄位 | 說明 |
|---------------------|-------------------|-------------------|------|
| `XxxId`（Identity VO）| `ProductId`, `SprintId` | `ProductId`, `SprintId` | ✅ **必須保持 VO** — ID 型別在所有層都用 VO |
| 簡單 VO（如 `ProductName`）| `ProductName` | `ProductName` | ✅ **必須保持 VO** — 開放型別，序列化穩定，型別安全 |
| 跨 Aggregate 參考 VO | `TeamId`, `SprintId` | `TeamId`, `SprintId` | ✅ **必須保持 VO** — 即使是外部 Aggregate 的 ID |
| **Enum**（如 `SprintState`）| `SprintState` | **`String`** | ⚠️ **唯一必須降級的型別** — 封閉集合，成員增刪改名會破壞歷史事件反序列化 |
| Primitive（如 `description`）| `String` | `String` | ✅ 直接使用（無對應 VO） |
| 複合 VO（如 `Timebox`）| `Timebox` | `Timebox` 或展開 | ✅ 視序列化複雜度決定 |

> **Why VO, not String?** 使用 VO 提供：
> 1. **型別安全**：`BoardId` 和 `TeamId` 不會搞混，`String` 和 `String` 編譯器無法區分
> 2. **消除 when() handler 的無謂轉換**：`this.id = event.boardId()` 直接賦值，不需要 `new BoardId(event.boardId())`
> 3. **一致性**：Event 是 Domain Model 的一部分，應該使用 Domain 的型別語言
>
> **Why Enum → String?** Enum 成員可能重新命名（`STARTED` → `IN_PROGRESS`），
> 若 Event 直接存 enum，歷史事件的 `SprintState.valueOf("STARTED")` 會拋
> `IllegalArgumentException`。用 String 儲存，由 `when()` 負責 legacy mapping。

```java
// ✅ CORRECT: Event record 使用 VO 型別（Enum 除外）
record BoardCreated(
    BoardId boardId,         // Identity VO — 必須保持 VO
    TeamId teamId,           // 跨 Aggregate 參考 VO — 必須保持 VO
    String name,             // primitive（aggregate.yaml 定義為 String，無對應 VO）
    Map<String, String> metadata,
    UUID id,
    Instant occurredOn
) implements BoardEvents, InternalDomainEvent.ConstructionEvent { }

// ✅ CORRECT: Enum 降級為 String
record SprintStarted(
    SprintId sprintId,
    String state,            // Enum SprintState → String（封閉集合，避免序列化耦合）
    Map<String, String> metadata,
    UUID id,
    Instant occurredOn
) implements SprintEvents { }

// ❌ WRONG: Aggregate 有 BoardId VO，Event 卻退化為 String
record BoardCreated(
    String boardId,          // ❌ Aggregate 有 BoardId VO，禁止退化！
    String teamId,           // ❌ Aggregate 有 TeamId VO，禁止退化！
    String name,
    ...
) { }

// ❌ WRONG: Enum 直接存在 Event 中
record SprintStarted(
    SprintId sprintId,
    SprintState state,       // ❌ Enum 成員改名會破壞歷史事件反序列化
    ...
) { }
```

**在 Aggregate 中的效果——VO 型別讓 when() handler 更乾淨**：
```java
// ✅ CORRECT: Event 用 VO，when() handler 直接賦值，無轉換
public Board(BoardId boardId, TeamId teamId, String name, String userId) {
    super();
    requireNotNull("boardId", boardId);
    requireNotNull("teamId", teamId);

    apply(new BoardEvents.BoardCreated(boardId, teamId, name, ...));
}

private void when(BoardEvents.BoardCreated event) {
    this.id = event.boardId();      // VO → VO，零轉換
    this.teamId = event.teamId();   // VO → VO，零轉換
    this.name = event.name();
}

// ❌ WRONG: Event 用 String，when() handler 被迫做無謂轉換
private void when(ProductEvents.ProductCreated event) {
    this.id = new ProductId(event.productId());   // String → VO，多此一舉
    this.name = new ProductName(event.name());    // String → VO，多此一舉
}
```

### Rule 4: Event Record Field Order

```java
// ✅ CORRECT: Consistent field ordering
record ProductCreated(
    // 1. Aggregate ID (FIRST)
    ProductId productId,

    // 2. Business fields
    String name,
    String description,      // nullable field OK

    // 3. Metadata (mutable Map)
    Map<String, String> metadata,

    // 4. Event ID (named 'id', not 'eventId')
    UUID id,

    // 5. Timestamp (LAST)
    Instant occurredOn
) implements ProductEvents, InternalDomainEvent.ConstructionEvent { }

// ❌ WRONG: Random field order
record ProductCreated(
    UUID id,                 // Should be near end
    String name,
    ProductId productId,     // Should be FIRST
    Instant occurredOn,
    Map<String, String> metadata
) { }
```

### Rule 5: Compact Constructor Validation

```java
// ✅ CORRECT: Compact constructor with null checks for required fields
record ProductCreated(
    ProductId productId,
    String name,
    String description,      // nullable - no null check
    Map<String, String> metadata,
    UUID id,
    Instant occurredOn
) implements ProductEvents, InternalDomainEvent.ConstructionEvent {

    public ProductCreated {
        Objects.requireNonNull(productId);
        Objects.requireNonNull(name);
        // description is nullable - no check
        Objects.requireNonNull(metadata);
        Objects.requireNonNull(id);
        Objects.requireNonNull(occurredOn);
    }

    @Override
    public Map<String, String> metadata() {
        return metadata;
    }

    // No source() override — inherits from interface default method
}

// ❌ WRONG: No compact constructor
record ProductCreated(...) implements ProductEvents {
    // Missing validation - will accept nulls
}
```

### Rule 6: Lifecycle Event Markers

```java
// ✅ CORRECT: Use framework interfaces
record ProductCreated(...)
    implements ProductEvents, InternalDomainEvent.ConstructionEvent { }

record ProductDeleted(...)
    implements ProductEvents, InternalDomainEvent.DestructionEvent { }

// Regular events - no marker
record ProductRenamed(...) implements ProductEvents { }

// ❌ WRONG: Self-defined interfaces
interface ConstructionEvent { }  // DON'T define your own!
record ProductCreated(...) implements ProductEvents, ConstructionEvent { }

// ❌ WRONG: Using wrong marker
record ProductCreated(...) implements ProductEvents, DestructionEvent { }
// Creation event should use ConstructionEvent, not DestructionEvent
```

### Rule 7: Inline mapper() with MAPPING_TYPE_PREFIX Constant

```java
// ✅ CORRECT: Interface-level constant + inline mapper with prefix pattern
public sealed interface ProductEvents extends InternalDomainEvent {

    String MAPPING_TYPE_PREFIX = "ProductEvents$";

    // ... aggregate ID method, source(), events ...

    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductRenamed", ProductRenamed.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductDeleted", ProductDeleted.class);
        return mapper;
    }
}

// ❌ WRONG: SCREAMING_SNAKE_CASE keys (does not follow project convention!)
mapper.put("PRODUCT_CREATED", ProductCreated.class);

// ❌ WRONG: TypeMapper inner class pattern (unnecessary complexity)
class TypeMapper extends DomainEventTypeMapper.DefaultMapper {
    // ... static block with mapper initialization
    public static DomainEventTypeMapper getInstance() { return mapper; }
}
static DomainEventTypeMapper mapper() {
    return TypeMapper.getInstance();
}

// ❌ WRONG: Key format using fully qualified class name
mapper.put(ProductCreated.class.getName(), ProductCreated.class);

// ❌ WRONG: Hard-coded string literal instead of MAPPING_TYPE_PREFIX constant
mapper.put("ProductEvents$ProductCreated", ProductCreated.class);  // Use constant!
```

**Rationale:**
- Key format: `"{AggregateEvents}${EventName}"` mirrors Java inner class naming convention
- `MAPPING_TYPE_PREFIX` as interface constant ensures consistency and single point of change
- Interface fields are implicitly `public static final` — no modifiers needed
- Inline mapper is simpler and sufficient for ADR-047 auto-registration

### Rule 8: Static mapper() Method for Auto-Registration (ADR-047)

```java
// ✅ CORRECT: Static method discovered by Spring ClassPath Scanning
public sealed interface ProductEvents extends InternalDomainEvent {

    // ... events ...

    String MAPPING_TYPE_PREFIX = "ProductEvents$";

    // This method is discovered by Spring ClassPath Scanning (ADR-047)
    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductRenamed", ProductRenamed.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductDeleted", ProductDeleted.class);
        return mapper;
    }
}

// ❌ WRONG: Missing mapper() method
// Events won't be auto-registered, causing serialization failures

// ❌ WRONG: Non-static method
default DomainEventTypeMapper mapper() {  // Must be static
    // ...
}
```

### Rule 9: Metadata Handling

> **Note**: Java records automatically generate accessors matching field names, so `metadata()` accessor
> technically exists without the `@Override`. However, we include the explicit `@Override public Map<String, String> metadata()`
> to clarify the framework interface contract (`InternalDomainEvent.metadata()`) — making the intent explicit
> and ensuring compilation fails immediately if the interface signature changes.

```java
// ✅ CORRECT: Each event implements metadata() method
record ProductCreated(
    ProductId productId,
    String name,
    Map<String, String> metadata,
    UUID id,
    Instant occurredOn
) implements ProductEvents, InternalDomainEvent.ConstructionEvent {

    // ... compact constructor ...

    @Override
    public Map<String, String> metadata() {
        return metadata;  // Return the mutable map
    }

    // No source() override — inherits from interface default method
}

// In Aggregate - use mutable HashMap
apply(new ProductEvents.ProductCreated(
    productId,
    name,
    new HashMap<>(),      // Mutable map for Use Case to add userId etc.
    UUID.randomUUID(),
    DateProvider.now()
));

// ❌ WRONG: Using immutable map
apply(new ProductEvents.ProductCreated(
    productId,
    name,
    Map.of(),             // Immutable! Use Case can't add metadata
    UUID.randomUUID(),
    DateProvider.now()
));
```

<!-- @authority: dateprovider_not_instant | source: rules/common-rules.md -->

### Rule 10: DateProvider Usage

```java
// ✅ CORRECT: Use DateProvider.now()
apply(new ProductEvents.ProductCreated(
    productId,
    name,
    new HashMap<>(),
    UUID.randomUUID(),
    DateProvider.now()    // Mockable in tests
));

// ❌ WRONG: Direct Instant.now()
apply(new ProductEvents.ProductCreated(
    productId,
    name,
    new HashMap<>(),
    UUID.randomUUID(),
    Instant.now()         // Not mockable - tests become non-deterministic
));
```

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Input Validation

Before generating code, verify:

| Check | Command | Expected |
|-------|---------|----------|
| aggregate.yaml exists | `test -f ${aggregateYamlPath}` | File exists |
| Has `domain_events` section | `grep "^domain_events:" ${aggregateYamlPath}` | Found |
| Has aggregate `name` | `grep "^name:" ${aggregateYamlPath}` | Found |

```
IF ANY CHECK FAILS:
  Report error: "Invalid aggregate.yaml: missing domain_events section"
  STOP - do not proceed
```

### Checkpoint 2: Pre-Generation Verification

Before writing any file, verify generated code has:

| Check | Verification |
|-------|--------------|
| Sealed interface | `public sealed interface ${Aggregate}Events extends InternalDomainEvent {` (no permits) |
| Aggregate ID method | `${Aggregate}Id ${aggregate}Id();` at interface level |
| source() default method | `default String source()` at interface level, returning `${aggregate}Id().value()` |
| No per-record source() | Records do NOT override `source()` — inherits from interface |
| **VO 型別一致性** | **Event record 欄位使用 Aggregate 已定義的 VO 型別（Enum 除外），禁止退化為 String** |
| mapper() method | `static DomainEventTypeMapper mapper()` with inline put calls |
| MAPPING_TYPE_PREFIX constant | Interface-level `String MAPPING_TYPE_PREFIX = "${Aggregate}Events$";` |
| Prefix key pattern | mapper keys like `MAPPING_TYPE_PREFIX + "ProductCreated"`, not `"PRODUCT_CREATED"` |

```
IF ANY CHECK FAILS:
  Fix the generated code before writing
```

### Checkpoint 3: Post-Generation Verification

After writing the file:

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify sealed interface structure (no permits clause)
grep -n "public sealed interface.*extends InternalDomainEvent {" ${outputFile}

# Verify NO TypeMapper inner class
grep -n "class TypeMapper" ${outputFile}
# Should return empty

# Verify inline mapper() method exists
grep -n "static DomainEventTypeMapper mapper()" ${outputFile}

# Verify MAPPING_TYPE_PREFIX constant and prefix key pattern
grep -n 'MAPPING_TYPE_PREFIX' ${outputFile}
# Should find interface constant and mapper.put calls using the constant
```

```
IF COMPILATION FAILS:
  Analyze error, fix, retry (max 3 attempts)

IF STRUCTURE CHECKS FAIL:
  This is a CRITICAL violation - fix immediately
```

---

## GENERATION TEMPLATES

### Step 1: Parse aggregate.yaml

Extract from `domain_events` section:
- Event names and their fields
- Which event is `ConstructionEvent`
- Which event is `DestructionEvent` (if any)
- Nullable fields

### Step 2: Generate Package Declaration

```java
package ${rootPackage}.${aggregateLowerCase}.entity;
```

### Step 3: Generate Imports

```java
import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
```

### Step 4: Generate Sealed Interface Declaration (No permits)

```java
public sealed interface ${Aggregate}Events extends InternalDomainEvent {
```

### Step 5: Generate Aggregate ID Method and source() Default Method

```java
    ${Aggregate}Id ${aggregateCamelCase}Id();

    @Override
    default String source() {
        return ${aggregateCamelCase}Id().value();
    }
```

### Step 6: Generate Event Records

For each event in `domain_events`:

```java
    record ${EventName}(
            ${Aggregate}Id ${aggregateCamelCase}Id,
            ${BusinessFields},
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ${Aggregate}Events${LifecycleMarker} {

        public ${EventName} {
            Objects.requireNonNull(${aggregateCamelCase}Id);
            ${RequiredFieldNullChecks}
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }
```

Where `${LifecycleMarker}` is:
- `, InternalDomainEvent.ConstructionEvent` for creation event
- `, InternalDomainEvent.DestructionEvent` for deletion event
- Empty for regular events

### Step 6.5: Generate MAPPING_TYPE_PREFIX Constant

Place after the source() default method, before event record definitions:

```java
    String MAPPING_TYPE_PREFIX = "${Aggregate}Events$";
```

### Step 7: Generate Inline mapper() Method

```java
    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        ${MapperPutStatements}
        return mapper;
    }
}
```

Where each `${MapperPutStatement}` is:
```java
        mapper.put(MAPPING_TYPE_PREFIX + "${EventName}", ${EventName}.class);
```

---

## EXAMPLE OUTPUT

For input `aggregate.yaml`:
```yaml
name: Product
domain_events:
  - name: ProductCreated
    type: construction
    fields:
      - name: name
        type: String
      - name: description
        type: String
        nullable: true
  - name: ProductRenamed
    fields:
      - name: newName
        type: String
  - name: ProductDeleted
    type: destruction
```

Generated `ProductEvents.java`:
```java
package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

public sealed interface ProductEvents extends InternalDomainEvent {

    ProductId productId();

    // source() 回傳 aggregate instance ID，DRY：interface 層級定義一次
    @Override
    default String source() {
        return productId().value();
    }

    String MAPPING_TYPE_PREFIX = "ProductEvents$";

    record ProductCreated(
            ProductId productId,
            String name,
            String description,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ProductEvents, InternalDomainEvent.ConstructionEvent {

        public ProductCreated {
            Objects.requireNonNull(productId);
            Objects.requireNonNull(name);
            // description is nullable
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record ProductRenamed(
            ProductId productId,
            String newName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ProductEvents {

        public ProductRenamed {
            Objects.requireNonNull(productId);
            Objects.requireNonNull(newName);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record ProductDeleted(
            ProductId productId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ProductEvents, InternalDomainEvent.DestructionEvent {

        public ProductDeleted {
            Objects.requireNonNull(productId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    // =========================================================================
    // Auto-Registration (ADR-047)
    // =========================================================================

    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductRenamed", ProductRenamed.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductDeleted", ProductDeleted.class);
        return mapper;
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

When called by `code executor`:

```
code executor
    ↓
    Step 4.1: aggregate-skill → ${Aggregate}.java
    ↓
    Step 4.1.1: domain-event-skill → ${Aggregate}Events.java  ← THIS SKILL
    ↓
    Step 4.1.2: value-object-skill → ${Aggregate}Id.java, other VOs
```

### Dependencies

This skill depends on knowing:
- Aggregate name (from aggregate.yaml)
- Event definitions (from aggregate.yaml → domain_events)

It does NOT depend on:
- Aggregate.java being generated first (can run in parallel if needed)

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| aggregate.yaml not found | Report error, STOP |
| Missing domain_events section | Report error, STOP |
| Compilation error | Analyze, fix, retry (max 3 attempts) |
| TypeMapper inner class generated | CRITICAL - remove and use inline mapper |
| Missing mapper() method | CRITICAL - must have for auto-registration |
| permits clause generated | Remove - let Java compiler infer |
| Per-record source() override | Remove — use interface-level default method only |
| aggregateId() method present | Remove — no longer exists in InternalDomainEvent |
| **VO 退化為 String** | **CRITICAL — Aggregate 已有 VO（如 BoardId, TeamId）時，Event record 禁止用 String 替代。修正為 VO 型別** |

---
