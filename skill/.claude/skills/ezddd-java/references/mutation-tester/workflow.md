# Mutation Tester Workflow

## Phase 1: Assess Current State

### Step 1: Run Baseline Mutation Testing

```bash
# 使用該 Aggregate 的所有 Use Case tests
mvn org.pitest:pitest-maven:mutationCoverage \
    -DtargetClasses=tw.teddysoft.aiscrum.<aggregate>.entity.<Aggregate> \
    -DtargetTests=tw.teddysoft.aiscrum.<aggregate>.usecase.service.*Test -q
```

### Step 2: Analyze Existing Contracts

```bash
grep -r "require\|ensure\|invariant" src/main/java/<entity-package>
```

### Step 3: Verify Existing Tests Pass

```bash
# 驗證 Use Case tests 全部通過
mvn test -Dtest='tw.teddysoft.aiscrum.<aggregate>.usecase.service.*Test' -q
```

---

## Phase 2: Incremental Contract Enhancement

### Priority Order (Safest First)

**Priority 1: Postconditions (Safest)**
```java
ensure("Result is in expected state", () ->
    this.state == ExpectedState.ACTIVE
);
```

**Priority 2: Invariants (Data Consistency)**
```java
invariant("Collection consistency", () ->
    this.items != null && this.count == this.items.size()
);
```

**Priority 3: Preconditions (Use Carefully)**
```java
require("Valid input", () ->
    input != null && !input.isEmpty()
);
```

### After Each Contract Addition

```bash
# Test immediately
mvn test -Dtest='<EntityName>*Test' -q

# If tests fail, rollback
git checkout -- <file>
```

---

## Phase 3: Create Assertion-Free Tests

```java
public class ProductBacklogItemAssertionFreeTest {

    @Test
    void exerciseCompleteLifecycle() {
        ProductId productId = ProductId.create();
        PbiId pbiId = PbiId.create();

        // Create aggregate
        ProductBacklogItem pbi = new ProductBacklogItem(
            productId, pbiId, "Test PBI", "creator-id"
        );

        // Exercise all methods
        pbi.changeDescription("New description");
        pbi.estimate(Estimate.valueOf(5));
        pbi.select(SprintId.valueOf(UUID.randomUUID().toString()), "user-id");
        pbi.unselect("user-id");

        // NO ASSERTIONS - Contracts verify correctness
    }

    @Test
    void exerciseContractViolations() {
        assertContractViolation(() ->
            new ProductBacklogItem(null, null, "", "")
        );
    }

    private void assertContractViolation(Runnable action) {
        try {
            action.run();
            fail("Expected contract violation");
        } catch (AssertionError | RuntimeException e) {
            // Contract violation detected - expected
        }
    }
}
```

---

## Phase 4: Verify Improvement

```bash
# Run mutation testing
mvn org.pitest:pitest-maven:mutationCoverage -q

# Compare metrics:
# - Line Coverage
# - Mutation Score
# - Test Strength
```

---

## Phase 5: Parallel Mode Execution (--parallel flag)

When `--parallel` flag is provided, execute mutation testing for multiple aggregates simultaneously.

### Step 1: Parse Aggregate List

```bash
# If --parallel all, auto-discover aggregates
find src/main/java -path "*/entity/*.java" -name "*.java" \
  ! -name "*Id.java" ! -name "*Events.java" ! -name "*State.java" \
  | xargs -I {} dirname {} | sort -u | xargs -I {} basename {}
```

### Step 2: Create Report Directory

```bash
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_DIR=".dev/mutation-reports/${TIMESTAMP}"
mkdir -p "${REPORT_DIR}"
```

Initialize `timing.json`:

```json
{
  "execution_id": "${TIMESTAMP}",
  "mode": "parallel",
  "started_at": "2026-01-06T09:00:00Z",
  "completed_at": null,
  "aggregates": {}
}
```

### Step 3: Launch Parallel Agents

For each aggregate, create a background Task agent:

```javascript
const agents = [];
for (const aggregate of aggregates) {
  const agent = Task({
    subagent_type: "general-purpose",
    prompt: `
你是 Mutation Testing 專家，負責為 ${aggregate} aggregate 執行 PIT mutation testing。

目標類別：tw.teddysoft.aiscrum.${aggregate.toLowerCase()}.entity.${aggregate}

執行步驟：
1. 執行 PIT mutation testing
2. 記錄結果到 ${REPORT_DIR}/${aggregate}.json
3. 返回精簡摘要（< 200 字元）

PIT 指令：
mvn org.pitest:pitest-maven:mutationCoverage \\
    -DtargetClasses=tw.teddysoft.aiscrum.${aggregate.toLowerCase()}.entity.${aggregate} \\
    -DtargetTests=tw.teddysoft.aiscrum.${aggregate.toLowerCase()}.*Test -q

結果 JSON 格式：
{
  "aggregate": "${aggregate}",
  "started_at": "ISO-8601",
  "completed_at": "ISO-8601",
  "duration_sec": N,
  "line_coverage": "XX%",
  "mutation_coverage": "XX%",
  "test_strength": "XX%",
  "mutants_killed": N,
  "mutants_survived": N,
  "mutants_total": N,
  "status": "success|failed",
  "error": null
}

⚠️ 重要：只返回一行摘要，詳細結果寫入檔案。
`,
    run_in_background: true,
    description: `PIT test ${aggregate}`
  });
  agents.push({ name: aggregate, task_id: agent.task_id });
}
```

### Step 4: Wait and Collect Results

```javascript
for (const agent of agents) {
  const result = TaskOutput({
    task_id: agent.task_id,
    block: true,
    timeout: 300000  // 5 minutes per aggregate
  });
  console.log(`${agent.name}: ${result}`);
}
```

### Step 5: Generate Consolidated Report

```markdown
# Parallel Mutation Testing Report

## Execution Summary
- **Started**: 2026-01-06 09:00:00
- **Completed**: 2026-01-06 09:08:30
- **Total Duration**: 8m 30s
- **Aggregates Tested**: 5

## Results by Aggregate

| Aggregate | Line Cov | Mutation Cov | Test Strength | Killed | Survived | Duration |
|-----------|----------|--------------|---------------|--------|----------|----------|
| Product | 85% | 78% | 82% | 156 | 44 | 1m 45s |
| Sprint | 88% | 81% | 85% | 203 | 47 | 2m 10s |
| ProductBacklogItem | 82% | 75% | 80% | 289 | 96 | 2m 30s |
| ScrumTeam | 90% | 83% | 87% | 124 | 25 | 1m 15s |
| Workflow | 79% | 72% | 78% | 312 | 121 | 2m 00s |
| **Average** | **85%** | **78%** | **82%** | - | - | - |

## Aggregates Below Threshold (< 75%)

| Aggregate | Mutation Cov | Gap | Recommendation |
|-----------|--------------|-----|----------------|
| Workflow | 72% | -3% | Add postconditions to lane operations |
```

### Parallel Mode Conflict Avoidance

| Rule | Description |
|------|-------------|
| **Different Aggregates** | ✅ Can run in parallel |
| **Same Aggregate** | ❌ Never parallel |
| **Report Files** | Each aggregate writes to separate JSON file |

---

## Phase 6: Spy Test Generation (--spy mode only)

### Step 1: Identify Surviving Postcondition Mutants

```bash
# Run PIT with TRUE_RETURNS enabled
mvn org.pitest:pitest-maven:mutationCoverage \
    -Dmutators=DEFAULTS,TRUE_RETURNS \
    -DtargetClasses=tw.teddysoft.aiscrum.<aggregate>.entity.<Entity> -q

# Extract surviving mutants
grep "SURVIVED.*TRUE_RETURNS" target/pit-reports/*/mutations.csv
```

### Step 2: Analyze Postcondition Methods

For each surviving mutant in `ensure()` lambda, identify:
1. The method being called in the postcondition
2. The parameters passed to that method
3. The aggregate method containing the postcondition

### Step 3: Generate Spy Test Class

Create `<Entity>PostconditionExecutionTest.java`:

```java
package tw.teddysoft.aiscrum.<aggregate>.entity;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.mockito.Mockito.*;

/**
 * Spy tests to verify postcondition methods are executed.
 * Generated by mutation-tester --spy to kill TRUE_RETURNS mutants.
 */
@DisplayName("<Entity> Postcondition Execution Tests")
public class <Entity>PostconditionExecutionTest {

    @Nested
    @DisplayName("POST-EXEC: <methodName>() postconditions")
    class <MethodName>Postconditions {

        @Test
        @DisplayName("POST-EXEC-1: <methodName>() calls <postconditionMethod>()")
        void <methodName>_executes_<postconditionMethod>_postcondition() {
            // Arrange
            <Entity> entity = Mockito.spy(create<Entity>());

            // Act
            entity.<methodName>(<parameters>);

            // Assert - verify postcondition method was called
            verify(entity).<postconditionMethod>(<expectedArgs>);
        }
    }

    private <Entity> create<Entity>() {
        return new <Entity>(<constructorArgs>);
    }
}
```

### Step 4: Generate Tests for Each Surviving Mutant

| Mutation Location | Postcondition | Generated Test |
|-------------------|---------------|----------------|
| `commitSprint:158` | `isSprintCommitted(sprintId)` | `verify(product).isSprintCommitted(sprintId)` |
| `setGoal:253` | `_hasGoal()` | `verify(product)._hasGoal()` |
| `markAsDeleted:328` | `_isDeletedFlagSet()` | `verify(product)._isDeletedFlagSet()` |

### Step 5: Verify Spy Tests Kill Mutants

```bash
# Run PIT again with TRUE_RETURNS
mvn org.pitest:pitest-maven:mutationCoverage \
    -Dmutators=DEFAULTS,TRUE_RETURNS \
    -DtargetClasses=tw.teddysoft.aiscrum.<aggregate>.entity.<Entity> \
    -DtargetTests=tw.teddysoft.aiscrum.<aggregate>.entity.<Entity>*Test -q

# Verify mutation score improved
```

### Spy Test Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| Class | `<Entity>PostconditionExecutionTest` | `ProductPostconditionExecutionTest` |
| Method | `<method>_executes_<check>_postcondition` | `commitSprint_executes_isSprintCommitted_postcondition` |
| DisplayName | `POST-EXEC-N: <description>` | `POST-EXEC-1: commitSprint() calls isSprintCommitted()` |

---

## Implementation Checklist

### Before Starting
- [ ] Verify POM has uContract exclusion
- [ ] Run baseline mutation testing
- [ ] Record current metrics

### During Implementation
- [ ] Identify low-coverage methods
- [ ] Add postconditions first
- [ ] Test after each contract
- [ ] Rollback if tests fail

### After Implementation
- [ ] Create assertion-free tests
- [ ] Run final mutation testing
- [ ] Compare metrics improvement
- [ ] Document findings

---

## Troubleshooting

### Problem: 0% Coverage from PIT

**Symptom**: PIT shows 0% but tests exist

**Solution**:
```bash
# First verify all tests pass
mvn test -Dtest='EntityName*Test' -q

# Fix failing tests, then run PIT
mvn org.pitest:pitest-maven:mutationCoverage -q
```

### Problem: Many Tests Fail After Adding Contracts

**Symptom**: 17/71 tests fail after adding contracts

**Solution**:
```bash
# Immediately rollback
git checkout -- <file>

# Use incremental approach:
# 1. Add ONE contract
# 2. Test immediately
# 3. Only continue if tests pass
```

### Problem: Mutation Score Improves Slowly

**Symptom**: Adding contracts but only +3% improvement

**Solution**:
- Analyze PIT report for uncovered mutations
- Add targeted contracts for specific methods
- Create assertion-free tests covering more paths

### Problem: uContract Being Mutated by PIT

**Symptom**: PIT report shows Contract methods being mutated

**Solution**: Verify POM configuration includes exclusions:

```xml
<avoidCallsTo>
    <avoidCallsTo>tw.teddysoft.ucontract.Contract</avoidCallsTo>
    <avoidCallsTo>tw.teddysoft.ucontract</avoidCallsTo>
</avoidCallsTo>
```
