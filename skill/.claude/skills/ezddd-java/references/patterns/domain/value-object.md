---
name: value-object-skill
description: |
  Generate Value Objects following DDD patterns.

  Triggered by:
  - code executor (Step 4.1.2)
  - Direct user request: "generate value object for [name]"

  Input: aggregate.yaml specification (from controlled-domain/ or workpiece/)
  Output: {Aggregate}Id.java, other Value Object files

  This skill embeds critical Value Object rules to ensure generated code
  is correct without relying on AI to read external files.

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Value Object Generation Skill

## Overview

This skill generates Value Object classes following DDD patterns.
It supports 4 categories of Value Objects, each with specific implementation rules.

---

## INPUT

| Source | Path |
|--------|------|
| CBF Frame | `JSON spec `aggregates[]`` |
| SWF Frame | `JSON spec `aggregates[]`` |

---

## OUTPUT

| File | Location |
|------|----------|
| Aggregate ID | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}Id.java` |
| Other Value Objects | `src/main/java/{rootPackage}/{aggregate}/entity/{ValueObject}.java` |

---

## VALUE OBJECT CATEGORIES

### Category 1: Aggregate/Entity ID

**Purpose:** Unique identifier for aggregates and entities.

**Required factory methods (3):** `valueOf(String)`, `valueOf(UUID)`, `create()`

```java
// Example: ProductId.java
public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
    }

    public static ProductId create() {
        return new ProductId(UUID.randomUUID().toString());
    }

    public static ProductId valueOf(String value) {
        return new ProductId(value);
    }

    public static ProductId valueOf(UUID value) {
        return new ProductId(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}
```

### Category 2: Simple Name/String Wrapper

**Purpose:** Wrap primitive types with domain meaning.

**Required factory methods (2):** `valueOf(String)`, `valueOf(UUID)` (no `create()`)

**IMPORTANT: Spec-Driven Validation** - Only add validations explicitly defined in the spec's `constraint` field.

```java
// Example: ProductName.java with constraint: non-null
public record ProductName(String value) implements ValueObject {
    public ProductName {
        Objects.requireNonNull(value, "ProductName cannot be null");
        // NOTE: Only add blank check if spec has "constraint: non-blank"
    }

    public static ProductName valueOf(String value) {
        return new ProductName(value);
    }

    public static ProductName valueOf(UUID value) {
        return new ProductName(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}

// Example: ProductName.java with constraint: non-null, non-blank
public record ProductName(String value) implements ValueObject {
    public ProductName {
        Objects.requireNonNull(value, "ProductName cannot be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException("ProductName cannot be blank");
        }
    }
    // ... same valueOf(String), valueOf(UUID), toString()
}
```

### Category 3: Complex Value Object

**Purpose:** Encapsulate multiple related values.

```java
// Example: Money.java
public record Money(BigDecimal amount, Currency currency) implements ValueObject {
    public Money {
        Objects.requireNonNull(amount, "amount cannot be null");
        Objects.requireNonNull(currency, "currency cannot be null");
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Amount cannot be negative");
        }
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }

    @Override
    public String toString() {
        return amount + " " + currency;
    }
}
```

### Category 4: Enum-like Value Object

**Purpose:** Fixed set of predefined values with behavior.

```java
// Example: Priority.java
public enum Priority implements ValueObject {
    LOW(1),
    MEDIUM(2),
    HIGH(3),
    CRITICAL(4);

    private final int level;

    Priority(int level) {
        this.level = level;
    }

    public int getLevel() {
        return level;
    }

    public boolean isHigherThan(Priority other) {
        return this.level > other.level;
    }
}
```

---

## SPEC-DRIVEN PRINCIPLE ⚠️

**This skill MUST only generate validations explicitly defined in the specification.**

| Spec Constraint | Generated Validation |
|-----------------|---------------------|
| `non-null` | `Objects.requireNonNull()` |
| `non-blank` | `if (value.isBlank()) throw ...` |
| `positive` | `if (value <= 0) throw ...` |
| `min=N` | `if (value < N) throw ...` |
| `max=N` | `if (value > N) throw ...` |

**DO NOT:**
- ❌ Assume Name types need blank checks (unless spec says `non-blank`)
- ❌ Add validations "for safety" that spec doesn't require
- ❌ Infer constraints from type names or conventions

**Rationale:**
- Spec is the Single Source of Truth
- AI should be a "faithful executor", not a "well-meaning guesser"
- Generated code must be 100% predictable from spec

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Implement ValueObject Interface

```java
// CORRECT
public record ProductId(String value) implements ValueObject {

// WRONG - Missing interface
public record ProductId(String value) {
```

**Rationale:** `ValueObject` interface marks the class as a DDD Value Object and enables framework integration.

### Rule 2: Use Compact Constructor with Objects.requireNonNull()

```java
// CORRECT: Compact constructor with Objects.requireNonNull()
public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
    }
}

// WRONG: Using Contract (require/ensure)
public record ProductId(String value) implements ValueObject {
    public ProductId {
        require("Value not null", () -> value != null);  // WRONG!
    }
}

// WRONG: Canonical constructor
public record ProductId(String value) implements ValueObject {
    public ProductId(String value) {
        this.value = Objects.requireNonNull(value);  // WRONG! Canonical form
    }
}
```

**Rationale:**
- Compact constructor is the idiomatic Java record pattern
- `Objects.requireNonNull()` is the standard for null checks in Value Objects
- Contract (`require`/`ensure`) is for Aggregate Root only, NOT Entity/Value Object/Service

### Rule 3: Override toString() to Return Raw Value

```java
// CORRECT: Return raw value for serialization compatibility
@Override
public String toString() {
    return value;
}

// WRONG: Default record toString() includes class name
// Default: ProductId[value=abc-123]  ← Breaks serialization!

// WRONG: Custom format
@Override
public String toString() {
    return "ProductId: " + value;  // Breaks deserialization!
}
```

**Rationale:** `toString()` is used by ORM mappers and event serializers. Must return the raw value for proper reconstruction.

### Rule 4: Factory Methods Pattern

**ID Value Objects** require 3 factory methods: `valueOf(String)`, `valueOf(UUID)`, `create()`
**Non-ID Value Objects** require 2 factory methods: `valueOf(String)`, `valueOf(UUID)`

```java
// CORRECT: For ID types — valueOf(String), valueOf(UUID), create()
public static ProductId create() {
    return new ProductId(UUID.randomUUID().toString());
}

public static ProductId valueOf(String value) {
    return new ProductId(value);
}

public static ProductId valueOf(UUID value) {
    return new ProductId(value.toString());
}

// CORRECT: For non-ID types — valueOf(String), valueOf(UUID) only (no create())
public static ProductName valueOf(String value) {
    return new ProductName(value);
}

public static ProductName valueOf(UUID value) {
    return new ProductName(value.toString());
}

// WRONG: Using of() for ID creation
public static ProductId of() {
    return new ProductId(UUID.randomUUID().toString());  // Use create()!
}

// WRONG: ID type missing valueOf(UUID)
public record ProductId(String value) implements ValueObject {
    // Only has valueOf(String) — missing valueOf(UUID) and create()!
}
```

**Rationale:**
- `create()`: Generates new ID with UUID - used when creating new aggregates (ID only)
- `valueOf(String)`: Reconstructs from existing String value - used by ORM/Event Store
- `valueOf(UUID)`: Reconstructs from UUID value - used by controllers and tests

### Rule 5: Use IllegalArgumentException for Validation

```java
// CORRECT: IllegalArgumentException for invalid input
public record StoryPoints(int value) implements ValueObject {
    public StoryPoints {
        if (value < 0) {
            throw new IllegalArgumentException("Story points cannot be negative");
        }
        if (value > 100) {
            throw new IllegalArgumentException("Story points cannot exceed 100");
        }
    }
}

// WRONG: Using Contract
public record StoryPoints(int value) implements ValueObject {
    public StoryPoints {
        require("Positive", () -> value >= 0);  // WRONG!
    }
}
```

**Rationale:** Value Objects are immutable data holders. Contract (`require`/`ensure`) is for Aggregate Root with DBC business contracts.

### Rule 6: Immutability is Mandatory

```java
// CORRECT: Record is immutable by default
public record ProductId(String value) implements ValueObject {
    // No setters possible
}

// CORRECT: Complex VO returns new instance
public Money add(Money other) {
    return new Money(this.amount.add(other.amount), this.currency);
}

// WRONG: Mutating method
public void setAmount(BigDecimal newAmount) {  // FORBIDDEN!
    this.amount = newAmount;
}
```

**Rationale:** Value Objects must be immutable. Any "change" operation returns a new instance.

### Rule 7: Equality Based on All Fields

```java
// CORRECT: Records automatically implement equals/hashCode based on all fields
public record Money(BigDecimal amount, Currency currency) implements ValueObject {
    // equals() and hashCode() are auto-generated
}

// WRONG: Custom equals that ignores some fields
@Override
public boolean equals(Object obj) {
    if (obj instanceof Money m) {
        return this.amount.equals(m.amount);  // Ignores currency!
    }
    return false;
}
```

**Rationale:** Value Object equality is based on all constituent values.

### Rule 8: No Entity References

```java
// CORRECT: Reference by ID
public record OrderLine(
    ProductId productId,
    int quantity,
    Money price
) implements ValueObject {
}

// WRONG: Direct entity reference
public record OrderLine(
    Product product,  // WRONG! Entity reference in VO
    int quantity,
    Money price
) implements ValueObject {
}
```

**Rationale:** Value Objects should not hold references to Entities. Use IDs instead.

### Rule 9: Package Location

```java
// CORRECT: Same package as Aggregate
package tw.teddysoft.aiscrum.product.entity;

public record ProductId(String value) implements ValueObject { }

// WRONG: Separate value-object package
package tw.teddysoft.aiscrum.product.valueobject;  // WRONG!

// WRONG: Common/shared package for all VOs
package tw.teddysoft.aiscrum.common.vo;  // WRONG!
```

**Rationale:** Value Objects belong to their Aggregate's bounded context, in the `entity` package.

### Rule 10: ID Types Must Support UUID String

```java
// CORRECT: ID accepts UUID string format, provides all 3 factory methods
public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
        // Note: Do NOT validate UUID format - allow any string for flexibility
    }

    public static ProductId create() {
        return new ProductId(UUID.randomUUID().toString());
    }

    public static ProductId valueOf(String value) {
        return new ProductId(value);
    }

    public static ProductId valueOf(UUID value) {
        return new ProductId(value.toString());
    }
}

// WRONG: Enforcing UUID format
public record ProductId(String value) implements ValueObject {
    public ProductId {
        try {
            UUID.fromString(value);  // WRONG! Too restrictive
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid UUID format");
        }
    }
}
```

**Rationale:** While `create()` generates UUIDs, the ID should accept any string to support legacy data and testing.

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Input Validation

Before generating code, verify:

| Check | Command | Expected |
|-------|---------|----------|
| aggregate.yaml exists | `test -f ${aggregateYamlPath}` | File exists |
| Has `attributes` field | `grep "^attributes:" ${aggregateYamlPath}` | Found |
| ID attribute defined | `grep "type:.*Id" ${aggregateYamlPath}` | Found |

```
IF ANY CHECK FAILS:
  Report error: "Invalid aggregate.yaml: missing required field"
  STOP - do not proceed
```

### Checkpoint 2: Pre-Generation Verification

Before writing any file:

| Check | Verification |
|-------|--------------|
| Implements ValueObject | Must have `implements ValueObject` |
| Compact constructor | Uses `Objects.requireNonNull()` |
| toString() override | Returns raw value only |
| No Contract usage | No `require`/`ensure` in Value Objects |

```
IF ANY CHECK FAILS:
  Fix the generated code
  Re-verify before writing
```

### Checkpoint 3: Post-Generation Verification

After writing the file:

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify ValueObject interface
grep "implements ValueObject" ${outputFile}
# Should return the class declaration line

# Verify no Contract usage
grep -E "require\(|ensure\(" ${outputFile}
# Should return empty
```

```
IF COMPILATION FAILS:
  Analyze error
  Fix and regenerate

IF CONTRACT USAGE FOUND:
  This is a violation of Value Object pattern
  Replace with Objects.requireNonNull() or IllegalArgumentException
```

---

## GENERATION TEMPLATES

### Step 1: Parse aggregate.yaml

Extract attributes and identify Value Objects:
- Attributes with `type: {Aggregate}Id` → Aggregate ID (Category 1)
- Attributes with `type: String` and semantic hints → Simple Name (Category 2)
- Attributes with multiple fields → Complex VO (Category 3)
- Attributes with fixed values → Enum-like (Category 4)

### Step 2: Generate Aggregate ID

**Always generate first** - Required by Aggregate and Events.

```java
package ${rootPackage}.${aggregateLowerCase}.entity;

import tw.teddysoft.ezddd.entity.ValueObject;
import java.util.Objects;
import java.util.UUID;

public record ${Aggregate}Id(String value) implements ValueObject {
    public ${Aggregate}Id {
        Objects.requireNonNull(value, "${Aggregate}Id value cannot be null");
    }

    public static ${Aggregate}Id create() {
        return new ${Aggregate}Id(UUID.randomUUID().toString());
    }

    public static ${Aggregate}Id valueOf(String value) {
        return new ${Aggregate}Id(value);
    }

    public static ${Aggregate}Id valueOf(UUID value) {
        return new ${Aggregate}Id(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}
```

### Step 3: Generate Other Value Objects

For each identified Value Object in aggregate.yaml:

**Category 2 (Simple Name):**

⚠️ **Spec-Driven**: Only add validations from the `constraint` field in aggregate.yaml.

```java
// If constraint: non-null (default)
public record ${Name}(String value) implements ValueObject {
    public ${Name} {
        Objects.requireNonNull(value, "${Name} cannot be null");
    }

    public static ${Name} valueOf(String value) {
        return new ${Name}(value);
    }

    public static ${Name} valueOf(UUID value) {
        return new ${Name}(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}

// If constraint: non-null, non-blank
public record ${Name}(String value) implements ValueObject {
    public ${Name} {
        Objects.requireNonNull(value, "${Name} cannot be null");
        if (value.isBlank()) {
            throw new IllegalArgumentException("${Name} cannot be blank");
        }
    }
    // ... same valueOf(String), valueOf(UUID), and toString()
}
```

**Category 3 (Complex):**
```java
public record ${Name}(${Field1Type} ${field1}, ${Field2Type} ${field2}) implements ValueObject {
    public ${Name} {
        Objects.requireNonNull(${field1}, "${field1} cannot be null");
        Objects.requireNonNull(${field2}, "${field2} cannot be null");
        // Additional validation rules
    }

    @Override
    public String toString() {
        return ${field1} + ":" + ${field2};
    }
}
```

**Category 4 (Enum-like):**
```java
public enum ${Name} implements ValueObject {
    ${VALUE1},
    ${VALUE2},
    ${VALUE3};
}
```

### Step 4: Verify All Generated Files

Run compilation check for all generated Value Objects.

---

## EXAMPLE OUTPUT

For input `aggregate.yaml`:
```yaml
name: Product
attributes:
  - name: id
    type: ProductId
  - name: name
    type: String
  - name: status
    type: ProductStatus
    values: [DRAFT, ACTIVE, ARCHIVED]
```

Generated files:

**ProductId.java:**
```java
package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;
import java.util.Objects;
import java.util.UUID;

public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
    }

    public static ProductId create() {
        return new ProductId(UUID.randomUUID().toString());
    }

    public static ProductId valueOf(String value) {
        return new ProductId(value);
    }

    public static ProductId valueOf(UUID value) {
        return new ProductId(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}
```

**ProductStatus.java:**
```java
package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

public enum ProductStatus implements ValueObject {
    DRAFT,
    ACTIVE,
    ARCHIVED
}
```

---

## INTEGRATION WITH ORCHESTRATOR

When called by `code executor`:

```
code executor
    ↓
    Step 4.1.2: Invoke value-object-skill
    ├─ Input: ${problemFramePath}/controlled-domain/aggregate.yaml
    ├─ Output: ${Aggregate}Id.java, other VOs
    └─ Next: Step 4.2 (use-case-skill)
```

---

## COMMON VALUE OBJECT TYPES

### Reference to Other Aggregate

When an aggregate references another aggregate's ID, **import it directly** — do NOT create a local copy:

```java
// In Sprint aggregate, referencing Product's ID
import [rootPackage].product.entity.ProductId;  // ✅ Import from source aggregate

public class Sprint extends EsAggregateRoot<SprintId, SprintEvents> {
    private ProductId productId;  // Cross-aggregate reference via import
}
```

> 🔴 **禁止在其他 Aggregate 套件中重新定義 Value Object**。
> Value Object 只定義一次，其他 Aggregate 透過 import 引用。
> 詳見 `references/rules/common-rules.md` — Cross-Aggregate Value Object Rules。

### Date/Time Value Objects

```java
// Prefer using Instant directly rather than wrapping
// If semantic meaning is needed:
public record DueDate(Instant value) implements ValueObject {
    public DueDate {
        Objects.requireNonNull(value, "DueDate cannot be null");
    }

    public boolean isOverdue() {
        return Instant.now().isAfter(value);
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
```

### Rule 11: Jackson Serialization Safety for Record VOs ⭐⭐⭐ CRITICAL

> **ROOT CAUSE (Workflow CBF Failure F4)**: Java records automatically serialize all `is*()` and `get*()`
> methods as JSON properties. If these methods are NOT constructor parameters, Jackson deserialization
> fails with `UnrecognizedPropertyException`. This error occurs inside the Relay thread and is
> **silently swallowed** — the only visible symptom is `ConditionTimeoutException` in tests.
>
> **Causation chain (6 hops, 3 silent)**:
> `is*() method → Jackson serializes as property → Relay deserializes → UnrecognizedPropertyException
> → Relay thread catches silently → Event never reaches MessageBroker → Test await() times out`

```java
// ✅ CORRECT: @JsonIgnore on all non-constructor accessor methods
import com.fasterxml.jackson.annotation.JsonIgnore;

public record WipLimit(int value) implements ValueObject {
    @JsonIgnore  // REQUIRED: prevents Jackson from treating isUnlimited() as "unlimited" property
    public boolean isUnlimited() { return value == -1; }
}

public record Money(BigDecimal amount, Currency currency) implements ValueObject {
    @JsonIgnore  // REQUIRED: not a constructor parameter
    public boolean isZero() { return amount.compareTo(BigDecimal.ZERO) == 0; }

    @JsonIgnore  // REQUIRED: derived from constructor params but not itself a param
    public String getDisplayValue() { return amount + " " + currency; }
}

// ❌ WRONG: Missing @JsonIgnore — causes UnrecognizedPropertyException at deserialization
public record WipLimit(int value) implements ValueObject {
    public boolean isUnlimited() { return value == -1; }
    // Jackson serializes: {"value": -1, "unlimited": true}
    // Deserialization fails: no "unlimited" constructor param in WipLimit(int value)
}
```

**Rule**: All non-constructor accessor methods (`is*()`, `get*()`, `has*()`) on Java record Value Objects
MUST be annotated with `@com.fasterxml.jackson.annotation.JsonIgnore`.

**Affected Method Patterns**:
| Pattern | Example | Action |
|---------|---------|--------|
| `is*()` returning boolean | `isUnlimited()`, `isExpired()` | Add `@JsonIgnore` |
| `get*()` returning computed value | `getDisplayName()`, `getFullValue()` | Add `@JsonIgnore` |
| `has*()` returning boolean | `hasValue()`, `hasExpired()` | Add `@JsonIgnore` |
| Record component accessor | `value()`, `amount()` | Do NOT add `@JsonIgnore` (these are constructor params) |

**Debugging Tip**: When `ConditionTimeoutException` occurs during event verification, always search
stdout/stderr for `UnrecognizedPropertyException` or `Jackson` — the real error may be hidden in the Relay thread.

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| aggregate.yaml not found | Report error, STOP |
| Missing ID attribute | Report error, STOP |
| Compilation error | Analyze, fix, retry (max 3 attempts) |
| Contract usage detected | Replace with IllegalArgumentException |
| `UnrecognizedPropertyException` on VO deserialization | Add `@JsonIgnore` to non-constructor `is*()`/`get*()`/`has*()` methods (Rule 11) |

---
