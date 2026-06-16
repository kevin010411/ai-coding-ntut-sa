# Aggregate Complete Review Mode

When reviewing an **Aggregate Root**, automatically include **ALL** related components in the same `[aggregate]/entity/` directory.

## Trigger

- User asks to review an Aggregate (e.g., "review Sprint aggregate", "code review ProductBacklogItem")
- File pattern matches `**/entity/{Aggregate}.java` or known Aggregates like `Sprint.java`, `Product.java`

## Execution Flow

### Step 1: Scan ALL Files in Entity Directory (MANDATORY)

```bash
# 使用 glob 取得所有 entity 目錄下的 Java 檔案
glob: **/[aggregate]/entity/*.java

# 排除測試檔案（*Test.java, *ContractTest.java）
```

**必須掃描目錄內的所有 .java 檔案，不可只取部分檔案！**

### Step 2: Categorize Each File

| Pattern | Type | Priority | Action |
|---------|------|----------|--------|
| `[Aggregate].java` | Aggregate Root | **CRITICAL** | Review (ES Compliance) |
| `*Events.java` | Domain Events | **CRITICAL** | Review (Event Design) |
| `*Id.java` | Value Object (ID) | HIGH | Review (VO Design) |
| `*State.java` (enum) | Enum Value Object | LOW | **SKIP** (enum 免檢) |
| Other `*.java` (class/record) | Internal Entity or VO | MEDIUM | Review (判斷類型) |
| `*Test.java` | Test | - | **SKIP** (不在此 review) |

**判斷 Internal Entity vs Value Object**:
- 有 `implements Entity<ID>` → Internal Entity
- 有 `implements ValueObject` 或是 `record` → Value Object
- 都沒有 → 需人工判斷

### Step 3: Include ALL Non-Exempt Files in Review

**強制規定**：必須將所有非 enum、非 test 的 .java 檔案納入 review！

```
# 範例：Product aggregate 完整掃描結果
product/entity/
├── Product.java              ← Aggregate Root (CRITICAL)
├── ProductEvents.java        ← Domain Events (CRITICAL)
├── ProductId.java            ← Value Object ID (HIGH)
├── ProductGoal.java          ← Internal Entity (MEDIUM)
├── ProductGoalId.java        ← Value Object ID (HIGH)
├── ProductName.java          ← Value Object (MEDIUM)
├── CommittedSprint.java      ← Internal Entity (MEDIUM)
├── DefinitionOfDone.java     ← Internal Entity (MEDIUM)
├── DoneCriterion.java        ← Internal Entity (MEDIUM)
├── GoalMetric.java           ← Value Object (MEDIUM)
├── ProductGoalState.java     ← SKIP (enum)
└── ProductLifecycleState.java← SKIP (enum)
```

### Step 4: Apply Appropriate Checklist to Each File

| File Type | Checklist Section | Key Checks |
|-----------|-------------------|------------|
| Aggregate Root | Aggregate Root Checklist | Constructor, when(), apply() |
| Domain Events | Domain Event Checklist | sealed interface, metadata, mapper() |
| Internal Entity | Entity Checklist | Entity<ID>, Objects.requireNonNull, equals/hashCode |
| Value Object | Value Object Checklist | ValueObject interface, immutable, factory methods |

### Step 5: Generate Combined Report

```markdown
## Aggregate Complete Review: [AggregateName]

### Scan Summary
- **Directory**: `[aggregate]/entity/`
- **Total Files Found**: N
- **Files Reviewed**: N (excluded M enum files)
- **Files Skipped**: M (enum types)

### Components Reviewed
| File | Type | Priority | Status | Issues |
|------|------|----------|--------|--------|
| Product.java | Aggregate Root | CRITICAL | PASS | 0 |
| ProductEvents.java | Domain Event | CRITICAL | PASS | 0 |
| ProductId.java | Value Object (ID) | HIGH | PASS | 0 |
| ProductGoalId.java | Value Object (ID) | HIGH | PASS | 0 |
| ProductGoal.java | Internal Entity | MEDIUM | WARN | 1 |
| ProductName.java | Value Object | MEDIUM | PASS | 0 |
| CommittedSprint.java | Internal Entity | MEDIUM | PASS | 0 |
| DefinitionOfDone.java | Internal Entity | MEDIUM | PASS | 0 |
| DoneCriterion.java | Internal Entity | MEDIUM | PASS | 0 |
| GoalMetric.java | Value Object | MEDIUM | PASS | 0 |

### Skipped Files (Enum - 免檢)
| File | Reason |
|------|--------|
| ProductGoalState.java | enum type |
| ProductLifecycleState.java | enum type |

### Issues by Category

#### CRITICAL (Aggregate Root + Domain Events)
[Details...]

#### HIGH (Value Object IDs)
[Details...]

#### MEDIUM (Internal Entities + Value Objects)
[Details...]

### Overall Rating: X/5 stars
### Verdict: APPROVED / REJECTED
```

## Key Validation Points

### Cross-Component Consistency

- [ ] Aggregate ID Value Object exists and is used correctly
- [ ] Domain Events use correct Aggregate ID type
- [ ] Internal Entities are only accessible through Aggregate Root
- [ ] All components use correct validation method:
  - Aggregate Root → `Contract.requireNotNull()`
  - Entity/Value Object/Domain Event → `Objects.requireNonNull()`

### Event Sourcing Consistency

- [ ] All state changes go through Domain Events
- [ ] Domain Events match Aggregate's `when()` switch cases
- [ ] ConstructionEvent/DestructionEvent correctly applied

## Common Issues

### 1. Missing Files
If expected files are missing (e.g., no `*Events.java`), flag as CRITICAL issue.

### 2. Orphan Entities
If an Entity exists but is never referenced from Aggregate Root, flag as SHOULD FIX.

### 3. Inconsistent ID Usage
If Aggregate uses `String` for ID instead of proper Value Object, flag as MUST FIX.
