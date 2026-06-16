---
name: persistent-object-skill
description: |
  Generate Data Class (Persistent Object) for Outbox Pattern.

  Triggered by:
  - code executor (Step 4.4)
  - Direct user request: "generate data class for [aggregate]"

  Input: Aggregate specification from aggregate.yaml
  Output: {Aggregate}Data.java implementing OutboxData<String>

  Data classes are JPA entities that persist aggregate state to the database.

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Persistent Object (Data Class) Generation Skill

## Overview

This skill generates JPA Data classes that implement `OutboxData<String>` for the Outbox Pattern.
Data classes are the persistence representation of domain aggregates.

---

## INPUT

| Source | Path |
|--------|------|
| Aggregate Spec | `JSON spec `aggregates[]`` |
| Domain Entity | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}.java` |

---

## OUTPUT

| File | Location |
|------|----------|
| Data Class | `src/main/java/{rootPackage}/{aggregate}/usecase/port/out/{Aggregate}Data.java` |
| Child Data Classes | `src/main/java/{rootPackage}/{aggregate}/usecase/port/out/{ChildEntity}Data.java` |

---

## ⛔ COMPILATION CHECKLIST — 產生 Data Class 前必查 ⛔

> **每個 Data class 必須滿足以下 6 項，缺一會導致編譯失敗或 Outbox 靜默資料遺失！**

```
╔══════════════════════════════════════════════════════════════════╗
║          DATA CLASS COMPILATION CHECKLIST                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  □ ① implements OutboxData<String>  ← MANDATORY! (Rule 1)       ║
║     → 缺少 = 所有 Config 類別編譯失敗                           ║
║                                                                  ║
║  □ ② @Transient on domainEventDatas + streamName (Rule 3)       ║
║     → 缺少 = JPA 嘗試持久化，DB schema 錯誤                    ║
║                                                                  ║
║  □ ③ @Version on version field (Rule 5)                         ║
║     → 缺少 = optimistic locking 失效                            ║
║                                                                  ║
║  □ ④ Override ALL 8 interface methods (Rule 7)                  ║
║     → getId/setId/getVersion/setVersion                         ║
║     → getDomainEventDatas/setDomainEventDatas                   ║
║     → getStreamName/setStreamName                               ║
║                                                                  ║
║  □ ⑤ 雙參數建構子 + 預設建構子 (Rule 8)                        ║
║     → new XxxData() delegates to new XxxData(0L)               ║
║     → domainEventDatas 初始化為 new ArrayList<>()              ║
║                                                                  ║
║  □ ⑥ Enum 用 String 儲存，禁止 @Enumerated (Rule 10)           ║
║     → @Enumerated on String = JPA 映射異常！                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Implement OutboxData<String> (INTERFACE, not class!)

⚠️ **CRITICAL**: `OutboxData<String>` is an **interface**, NOT a class!
- ✅ `implements OutboxData<String>` — CORRECT
- ❌ `extends OutboxData` — WRONG (OutboxData is not a class, and missing `<String>` type parameter)
- ❌ `extends OutboxData<String>` — WRONG (OutboxData is an interface, use `implements`)

```java
// ✅ CORRECT: Implements OutboxData<String> (interface with generic type parameter)
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxData;

@Entity
@Table(name = "product")
public class ProductData implements OutboxData<String> {
    // Must implement ALL interface methods: getId, setId, getVersion, setVersion,
    // getDomainEventDatas, setDomainEventDatas, getStreamName, setStreamName
}

// ❌ WRONG: Missing interface
@Entity
public class ProductData {  // No OutboxData!
}

// ❌ WRONG: Using extends instead of implements
@Entity
public class ProductData extends OutboxData {  // OutboxData is an INTERFACE, not a class!
}

// ❌ WRONG: Missing generic type parameter
@Entity
public class ProductData implements OutboxData {  // Missing <String>!
}
```

**Rationale:** OutboxData interface provides the contract for domain event storage.

### Rule 2: Jakarta Persistence (NOT javax)

```java
// ✅ CORRECT: Jakarta persistence
import jakarta.persistence.*;

// ❌ WRONG: Old javax persistence
import javax.persistence.*;  // OUTDATED!
```

**Rationale:** Spring Boot 3.x uses Jakarta EE 9+, which renamed javax to jakarta.

### Rule 3: @Transient on domainEventDatas and streamName

> **核心原則**：`domainEventDatas` 和 `streamName` 的 `@Transient` **必須放在 field 宣告上**。
> 此外，當這些 field 透過 OutboxData interface override methods 暴露時，
> override methods **也需要** `@Transient`（見 Rule 7），以防止 JPA property discovery 衝突。

```java
// ✅ CORRECT: @Transient on field declarations（必須）
@Transient
private List<DomainEventData> domainEventDatas;

@Transient
private String streamName;

// ❌ WRONG: 只在 getter 上標 @Transient，field 上沒標
// （JPA field access 會忽略 method-level @Transient，導致持久化錯誤）
private List<DomainEventData> domainEventDatas;  // 缺少 @Transient!

@Transient
public List<DomainEventData> getDomainEventDatas() { }  // 光在這裡標不夠
```

**Rationale:** These fields are used during transaction but not persisted to database.
Field-level `@Transient` is the primary mechanism; method-level `@Transient` on interface
overrides (Rule 7) is additionally required to prevent JPA accessor-based property discovery.

### Rule 4: Explicit @Column(name) for ALL Fields

```java
// ✅ CORRECT: Explicit column names
@Column(name = "creatorId", nullable = false)
private String creatorId;

@Column(name = "productName", nullable = false)
private String productName;

// ❌ WRONG: No @Column - Hibernate converts to snake_case
private String creatorId;  // Becomes "creator_id" in SQL!
private String productName;  // Becomes "product_name" in SQL!
```

**Rationale:** Hibernate's default naming strategy converts camelCase to snake_case.

### Rule 5: @Version for Optimistic Locking

```java
// ✅ CORRECT: @Version field with default value
@Version
@Column(columnDefinition = "bigint DEFAULT 0", nullable = false)
private long version;

// ❌ WRONG: No @Version
private long version;  // No optimistic locking!

// ❌ WRONG: Wrong default syntax
@Column(nullable = false, defaultValue = "0")  // defaultValue doesn't exist!
```

**Rationale:** @Version enables optimistic locking for concurrent modifications.

### Rule 6: @Id with Explicit Column Name

```java
// ✅ CORRECT: @Id with explicit column
@Id
@Column(name = "id")
private String productId;

// ❌ WRONG: @Id without column name
@Id
private String productId;  // Column name unclear!
```

### Rule 7: OutboxData Interface Methods

```java
// ✅ CORRECT: Implement all required methods
@Override
@Transient
public String getId() {
    return productId;
}

@Override
@Transient
public void setId(String id) {
    this.productId = id;
}

@Override
public long getVersion() {
    return version;
}

@Override
public void setVersion(long version) {
    this.version = version;
}

@Override
@Transient
public List<DomainEventData> getDomainEventDatas() {
    return this.domainEventDatas;
}

@Override
@Transient
public void setDomainEventDatas(List<DomainEventData> domainEventDatas) {
    this.domainEventDatas = domainEventDatas;
}

@Override
@Transient
public String getStreamName() {
    return streamName;
}

@Override
@Transient
public void setStreamName(String streamName) {
    this.streamName = streamName;
}
```

### Rule 8: Default Constructor with Version Initialization

```java
// ✅ CORRECT: Two constructors
public ProductData() {
    this(0L);
}

public ProductData(long version) {
    this.version = version;
    this.domainEventDatas = new ArrayList<>();
    this.isDeleted = false;
}

// ❌ WRONG: No default constructor (JPA requires it)
// ❌ WRONG: Not initializing domainEventDatas
```

### Rule 9: Child Entities / Collections — JSON Column in Same Table

> **原則**: Aggregate 內部的子 Entity 和集合一律用 JSON 字串存在同一張 table，
> 不建立子表（見 Rule 11）。

```java
// ✅ CORRECT: 子 Entity 集合用 JSON 字串存在同一 table
@Column(name = "committedSprintIdsJson", columnDefinition = "TEXT")
private String committedSprintIdsJson;  // JSON: ["sprint-1", "sprint-2"]

// ✅ CORRECT: 複雜子 Entity 用 JSON 字串
@Column(name = "goalMetricsJson", columnDefinition = "TEXT")
private String goalMetricsJson;  // JSON: [{"name":"NPS","baseline":0.5,"target":0.8}, ...]

// Mapper 負責 serialize/deserialize
// toData():  data.setCommittedSprintIdsJson(objectMapper.writeValueAsString(sprintIds));
// toDomain(): List<String> ids = objectMapper.readValue(data.getCommittedSprintIdsJson(), ...);

// ❌ WRONG: OneToMany 建立子表 — 違反 single-table 原則
@OneToMany(cascade = CascadeType.ALL, mappedBy = "productData")
private Set<CommittedSprintData> committedSprintDatas;
```

### Rule 10: Enum Storage as String

> **⛔ CRITICAL — COMMON FIRST-GEN FAILURE CAUSE ⛔**
> PO 中 enum 欄位**必須用 `String` 型別儲存**，**禁止**使用 `@Enumerated` 註解。
> `@Enumerated` 只適用於 Java enum 型別欄位；用在 `String` 上會導致 JPA 映射異常。
> PO 屬於 infrastructure 層，不應依賴 domain enum 類別。

```java
// ✅ CORRECT (推薦): String field，不加 @Enumerated
@Column(name = "state", nullable = false)
private String state;

// ❌ WRONG: @Enumerated on String type — JPA 映射異常！
@Enumerated(EnumType.STRING)
private String state;

// ❌ WRONG: Domain enum in PO — 違反 Clean Architecture 分層
@Enumerated(EnumType.STRING)
@Column(name = "state")
private ProductState state;
```

### Rule 11: Single-Table Storage — Aggregate 內部物件與 Aggregate 同表

> **⚠️ 核心原則 ⚠️**
> **所有 Aggregate 內部的物件（Entity、Value Object、集合）一律與 Aggregate 儲存在同一張 table。**
> 不建立子表（OneToMany）或關聯表（ElementCollection）。
>
> - 簡單欄位 → 直接作為 table 的 column
> - 複雜物件或集合 → 序列化為 **JSON 字串**存在同一張 table 的 column 中

```java
// ── 簡單 Value Object：展開為同一 table 的多個 column ──
// ProductGoal(title, description, state) → 3 個 column
@Column(name = "goalTitle")
private String goalTitle;

@Column(name = "goalDescription")
private String goalDescription;

@Column(name = "goalState")
private String goalState;

// ── 複雜物件或集合：JSON 字串存在同一 table ──
@Column(name = "goalMetricsJson", columnDefinition = "TEXT")
private String goalMetricsJson;  // JSON: [{"name":"...", "baseline":0.5}, ...]

@Column(name = "committedSprintIdsJson", columnDefinition = "TEXT")
private String committedSprintIdsJson;  // JSON: ["sprint-1", "sprint-2", ...]
```

```java
// ❌ WRONG: 建立子表 — 違反 single-table 原則
@OneToMany(cascade = CascadeType.ALL, mappedBy = "productData")
private Set<GoalMetricData> goalMetricDatas;  // 會建立獨立的 goal_metric_data 表！

// ❌ WRONG: 建立關聯表 — 違反 single-table 原則
@ElementCollection
@CollectionTable(name = "product_sprint_ids")
private Set<String> committedSprintIds;  // 會建立獨立的 product_sprint_ids 表！
```

### Rule 12: Sync Data Fields When Adding New Aggregate Behaviors

> **⚠️ CRITICAL — COMMON MULTI-FRAME FAILURE CAUSE ⚠️**
> 每當新增 Aggregate 行為（如 `setGoal()`, `addMetric()`, `commitSprint()`）產生新的
> Entity/VO 狀態時，**必須同步更新 Data class 的 JPA 欄位**。否則 Outbox Profile 下
> save/load 後新狀態為 null，導致斷言失敗。

**同步檢查清單（每次新增行為後）：**

| 步驟 | 動作 | 範例 |
|------|------|------|
| 1 | 在 Data class 新增對應的 JPA 欄位（同一 table） | 簡單：`goalTitle` column / 複雜：`goalMetricsJson` JSON column |
| 2 | 新增 getter/setter | `getGoalTitle()`, `setGoalTitle()` |
| 3 | 更新 Mapper `toData()` 寫入新欄位 | `data.setGoalTitle(aggregate.getGoal().title())` |
| 4 | 更新 Mapper `toDomain()` 重建新狀態 | `aggregate.setGoal(...)` + `clearDomainEvents()` |

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Verification |
|-------|--------------|
| Aggregate exists | Domain entity file exists |
| Attributes defined | aggregate.yaml has attributes section |

### Checkpoint 2: Post-Generation

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify implements OutboxData
grep "implements OutboxData<String>" ${dataFile}

# Verify Jakarta imports
grep "import jakarta.persistence" ${dataFile}

# Verify no javax imports
grep "import javax.persistence" ${dataFile}
# Should return empty
```

---

## GENERATION TEMPLATES

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port.out;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxData;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "${tableName}")
public class ${Aggregate}Data implements OutboxData<String> {

    @Transient
    private List<DomainEventData> domainEventDatas;

    @Transient
    private String streamName;

    @Id
    @Column(name = "id")
    private String ${aggregateCamelCase}Id;

    // Add fields from aggregate.yaml
    @Column(name = "${fieldName}", nullable = ${nullable})
    private ${FieldType} ${fieldName};

    // isDeleted field (always include)
    @Column(name = "isDeleted", nullable = false)
    private boolean isDeleted;

    // Timestamps
    @Column(name = "createdAt", nullable = false)
    private Instant createdAt;

    @Column(name = "lastUpdated", nullable = false)
    private Instant lastUpdated;

    // Version for optimistic locking
    @Version
    @Column(columnDefinition = "bigint DEFAULT 0", nullable = false)
    private long version;

    // Default constructor
    public ${Aggregate}Data() {
        this(0L);
    }

    public ${Aggregate}Data(long version) {
        this.version = version;
        this.domainEventDatas = new ArrayList<>();
        this.isDeleted = false;
    }

    // Getters and setters for all fields
    // ...

    // OutboxData interface implementation
    @Override
    @Transient
    public String getId() {
        return ${aggregateCamelCase}Id;
    }

    @Override
    @Transient
    public void setId(String id) {
        this.${aggregateCamelCase}Id = id;
    }

    @Override
    public long getVersion() {
        return version;
    }

    @Override
    public void setVersion(long version) {
        this.version = version;
    }

    @Override
    @Transient
    public List<DomainEventData> getDomainEventDatas() {
        return this.domainEventDatas;
    }

    @Override
    @Transient
    public void setDomainEventDatas(List<DomainEventData> domainEventDatas) {
        this.domainEventDatas = domainEventDatas;
    }

    @Override
    @Transient
    public String getStreamName() {
        return streamName;
    }

    @Override
    @Transient
    public void setStreamName(String streamName) {
        this.streamName = streamName;
    }
}
```

---

## EXAMPLE OUTPUT

### ProductData.java

```java
package tw.teddysoft.aiscrum.product.usecase.port.out;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxData;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "product")
public class ProductData implements OutboxData<String> {

    @Transient
    private List<DomainEventData> domainEventDatas;

    @Transient
    private String streamName;

    @Id
    @Column(name = "id")
    private String productId;

    @Column(name = "productName", nullable = false)
    private String productName;

    @Column(name = "creatorId", nullable = false)
    private String creatorId;

    @Column(name = "isDeleted", nullable = false)
    private boolean isDeleted;

    @Column(name = "createdAt", nullable = false)
    private Instant createdAt;

    @Column(name = "lastUpdated", nullable = false)
    private Instant lastUpdated;

    @Version
    @Column(columnDefinition = "bigint DEFAULT 0", nullable = false)
    private long version;

    public ProductData() {
        this(0L);
    }

    public ProductData(long version) {
        this.version = version;
        this.domainEventDatas = new ArrayList<>();
        this.isDeleted = false;
    }

    // Getters and setters
    public String getProductId() { return productId; }
    public void setProductId(String productId) { this.productId = productId; }

    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }

    public String getCreatorId() { return creatorId; }
    public void setCreatorId(String creatorId) { this.creatorId = creatorId; }

    public boolean isDeleted() { return isDeleted; }
    public void setDeleted(boolean deleted) { isDeleted = deleted; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(Instant lastUpdated) { this.lastUpdated = lastUpdated; }

    // OutboxData interface
    @Override
    @Transient
    public String getId() { return productId; }

    @Override
    @Transient
    public void setId(String id) { this.productId = id; }

    @Override
    public long getVersion() { return version; }

    @Override
    public void setVersion(long version) { this.version = version; }

    @Override
    @Transient
    public List<DomainEventData> getDomainEventDatas() { return this.domainEventDatas; }

    @Override
    @Transient
    public void setDomainEventDatas(List<DomainEventData> domainEventDatas) {
        this.domainEventDatas = domainEventDatas;
    }

    @Override
    @Transient
    public String getStreamName() { return streamName; }

    @Override
    @Transient
    public void setStreamName(String streamName) { this.streamName = streamName; }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.4: Invoke persistent-object-skill
    ├─ Input: aggregate.yaml, {Aggregate}.java
    ├─ Output: {Aggregate}Data.java
    └─ Next: mapper-skill (Step 4.5)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| javax.persistence import | Replace with jakarta.persistence |
| Missing @Transient on domainEventDatas | Add @Transient annotation |
| Column name mismatch | Add explicit @Column(name=...) |
| Compilation error | Analyze, fix, retry |

---
