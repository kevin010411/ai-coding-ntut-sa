---
name: contract-test-skill
description: |
  Generate Aggregate Contract Tests for DBC (Design by Contract) verification.

  Triggered by:
  - code executor (Step 4.1.5)
  - Direct user request: "generate contract tests for [aggregate]"

  Input: Aggregate entity with require/ensure/invariant contracts
  Output: {Aggregate}ContractTest.java

  Contract tests verify Preconditions, Postconditions, and Invariants
  using pure JUnit 5 (no Spring required).

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Contract Test Generation Skill

## Overview

This skill generates Aggregate Contract Tests that verify DBC (Design by Contract):
- **Preconditions (require)** - Conditions that must be true before method execution
- **Postconditions (ensure)** - Conditions that must be true after method execution
- **Invariants** - Conditions that must always hold after any operation

---

## INPUT

| Source | Path |
|--------|------|
| Aggregate Entity | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}.java` |
| Domain Events | `src/main/java/{rootPackage}/{aggregate}/entity/{Aggregate}Events.java` |
| Aggregate Spec | `JSON spec `aggregates[]`` |

---

## OUTPUT

| File | Location |
|------|----------|
| Contract Test | `src/test/java/{rootPackage}/{aggregate}/entity/{Aggregate}ContractTest.java` |

---

## TEST CATEGORIES

### Category 1: Precondition Tests

Verify that methods reject invalid states or inputs.

**State precondition** (`require()`): Verify exception type is sufficient.
```java
@Test
@DisplayName("start() requires PLANNED state")
void start_rejects_non_planned_state() {
    Sprint sprint = createSprintWithState(SprintState.STARTED);

    assertThrows(PreconditionViolationException.class,
            () -> sprint.start("scrum-master-1"));
}
```

**Null precondition** (`requireNotNull()`): MUST also verify exception message identifies the null field.
```java
@Test
@DisplayName("constructor rejects null productId")
void constructor_rejects_null_productId() {
    assertThatThrownBy(() -> new Product(null, ProductName.valueOf("Test"), null, null, "user-1"))
            .isInstanceOf(PreconditionViolationException.class)
            .hasMessageContaining("productId");
}
```

### Category 2: Postcondition Tests (State)

Verify that methods produce correct state changes.

```java
@Test
@DisplayName("start() ensures state becomes STARTED")
void start_ensures_state_is_STARTED() {
    Sprint sprint = createSprintWithState(SprintState.PLANNED);

    sprint.start("scrum-master-1");

    assertThat(sprint.getState()).isEqualTo(SprintState.STARTED);
}
```

### Category 3: Postcondition Tests (Event)

Verify that methods emit correct domain events.

```java
@Test
@DisplayName("start() emits SprintStarted event")
void start_emits_SprintStarted_event() {
    Sprint sprint = createSprintWithState(SprintState.PLANNED);

    sprint.start("scrum-master-1");

    assertThat(sprint.getDomainEvents())
        .hasSize(1)
        .first()
        .isInstanceOf(SprintEvents.SprintStarted.class);
}
```

### Category 4: Invariant Tests

Verify that invariants hold after operations.

```java
@Test
@DisplayName("rename() maintains non-null name invariant")
void rename_maintains_name_invariant() {
    Workflow workflow = createWorkflow();

    workflow.rename("New Name", "user-1");

    assertThat(workflow.getName()).isNotNull();
    assertThat(workflow.getName().value()).isNotBlank();
}
```

### Category 5: Idempotency Tests (ignore() pattern)

Verify that idempotent operations are no-ops when already in target state.

```java
@Test
@DisplayName("select() is idempotent - same sprint selection is no-op")
void select_is_idempotent_for_same_sprint() {
    ProductBacklogItem pbi = createPbiInBacklog();
    SprintId sprintId = SprintId.valueOf(UUID.randomUUID().toString());

    // First selection
    pbi.select(sprintId, "user-1");
    pbi.clearDomainEvents();

    // Second selection with same sprint - should be no-op
    pbi.select(sprintId, "user-1");

    // Verify: no new events emitted (idempotent)
    assertThat(pbi.getDomainEvents()).isEmpty();
    assertThat(pbi.getState()).isEqualTo(PbiState.SELECTED);
}
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: No Spring Required

```java
// ✅ CORRECT: Pure JUnit 5
@DisplayName("Sprint Aggregate Contracts")
public class SprintContractTest {
    // No @SpringBootTest, no @Autowired
}

// ❌ WRONG: Using Spring
@SpringBootTest
public class SprintContractTest {
```

**Rationale:** Contract tests verify aggregate behavior in isolation, no infrastructure needed.

### Rule 2: Precondition Test Assertion Strategy

**Two strategies based on precondition type:**

#### 2a. State precondition (`require()`) — assertThrows is acceptable
```java
// ✅ CORRECT: assertThrows for state preconditions
assertThrows(PreconditionViolationException.class,
        () -> sprint.start("user-1"));
```

#### 2b. Null precondition (`requireNotNull()`) — MUST verify exception message contains field name
```java
// ✅ CORRECT: assertThatThrownBy verifies BOTH exception type AND field name in message
assertThatThrownBy(() -> new Product(null, ProductName.valueOf("Test"), null, null, "user-1"))
        .isInstanceOf(PreconditionViolationException.class)
        .hasMessageContaining("productId");

// ❌ WRONG: Only verifying exception type — does NOT confirm which field is null!
assertThrows(PreconditionViolationException.class,
        () -> new Product(null, ProductName.valueOf("Test"), null, null, "user-1"));
```

> **Rationale:** `requireNotNull("fieldName", value)` embeds the field name in the exception message.
> Only verifying `PreconditionViolationException` is thrown does NOT prove the exception identifies
> the null field — spec conditions like "The exception identifies the null field" require `hasMessageContaining`.

#### Common wrong patterns
```java
// ❌ WRONG: Using generic Exception
assertThrows(Exception.class, () -> sprint.start("user-1"));

// ❌ WRONG: Using IllegalStateException
assertThrows(IllegalStateException.class, () -> sprint.start("user-1"));
```

### Rule 3: assertThat for Postcondition Tests

```java
// ✅ CORRECT: Use assertThat (AssertJ) for state verification
import static org.assertj.core.api.Assertions.assertThat;

assertThat(sprint.getState()).isEqualTo(SprintState.STARTED);
assertThat(sprint.getDomainEvents())
    .hasSize(1)
    .first()
    .isInstanceOf(SprintEvents.SprintStarted.class);

// ❌ WRONG: Using JUnit assertEquals
assertEquals(SprintState.STARTED, sprint.getState());  // Less readable
```

### Rule 4: @Nested Class per Command Method

```java
// ✅ CORRECT: Clear organization with @Nested
@DisplayName("Sprint Aggregate Contracts")
public class SprintContractTest {

    @Nested
    @DisplayName("start() Contracts")
    class StartContracts {
        // Precondition tests
        // Postcondition tests
    }

    @Nested
    @DisplayName("cancel() Contracts")
    class CancelContracts {
        // Precondition tests
        // Postcondition tests
    }

    @Nested
    @DisplayName("complete() Contracts")
    class CompleteContracts {
        // Precondition tests
        // Postcondition tests
    }
}

// ❌ WRONG: Flat structure
public class SprintContractTest {
    @Test void start_test1() { }
    @Test void cancel_test1() { }
    @Test void start_test2() { }  // Mixed!
}
```

### Rule 5: Test Method Naming Convention

```java
// ✅ CORRECT: Precondition naming
void {methodName}_rejects_{invalidCondition}()
// Examples:
void start_rejects_non_planned_state()
void cancel_rejects_already_cancelled_sprint()
void complete_rejects_non_started_sprint()

// ✅ CORRECT: Postcondition naming
void {methodName}_ensures_{expectedOutcome}()
void {methodName}_emits_{EventName}_event()
// Examples:
void start_ensures_state_is_STARTED()
void start_emits_SprintStarted_event()
void cancel_ensures_reason_is_recorded()

// ❌ WRONG: Vague names
void test_start()
void should_work()
void cancel_test()
```

### Rule 6: @DisplayName Must Describe Contract

```java
// ✅ CORRECT: Descriptive DisplayName - Preconditions
@DisplayName("start() requires PLANNED state")
@DisplayName("cancel() rejects already CANCELLED sprint")
@DisplayName("complete() requires STARTED state")

// ✅ CORRECT: Descriptive DisplayName - Postconditions
@DisplayName("start() ensures state becomes STARTED")
@DisplayName("start() emits SprintStarted event")
@DisplayName("cancel() ensures reason is recorded")

// ❌ WRONG: Generic DisplayName
@DisplayName("test start")
@DisplayName("cancel test")
@DisplayName("should work")
```

### Rule 7: Helper Method for Aggregate Creation

```java
// ✅ CORRECT: Unified helper method
private Sprint createSprintWithState(SprintState state) {
    return new Sprint(
            ProductId.valueOf(UUID.randomUUID().toString()),
            SprintId.valueOf(UUID.randomUUID().toString()),
            SprintName.valueOf("Test Sprint"),
            null,
            Timebox.of(LocalDateTime.now().plusDays(1),
                       LocalDateTime.now().plusDays(15),
                       ZoneId.of("Asia/Taipei")),
            state,
            null, null, null, null,
            null, "scrum-master-1", null
    );
}

// Usage
Sprint sprint = createSprintWithState(SprintState.PLANNED);
Sprint startedSprint = createSprintWithState(SprintState.STARTED);

// ❌ WRONG: Repeating constructor calls in each test
@Test void test1() {
    Sprint sprint = new Sprint(...long constructor...);
}
@Test void test2() {
    Sprint sprint = new Sprint(...long constructor...);  // Duplication!
}
```

### Rule 8: clearDomainEvents() for Multi-Step Setup

```java
// ✅ CORRECT: Clear events from setup operations
private Sprint createStartedSprint() {
    Sprint sprint = createSprintWithState(SprintState.PLANNED);
    sprint.start("scrum-master-1");
    sprint.clearDomainEvents();  // CRITICAL: Clear the SprintStarted event
    return sprint;
}

@Test
void complete_emits_SprintCompleted_event() {
    Sprint sprint = createStartedSprint();  // Already STARTED, events cleared

    sprint.complete(Instant.now());

    // Only SprintCompleted event, not SprintStarted
    assertThat(sprint.getDomainEvents())
        .hasSize(1)
        .first()
        .isInstanceOf(SprintEvents.SprintCompleted.class);
}

// ❌ WRONG: Not clearing setup events
@Test
void complete_emits_SprintCompleted_event() {
    Sprint sprint = createSprintWithState(SprintState.PLANNED);
    sprint.start("scrum-master-1");  // This adds SprintStarted event

    sprint.complete(Instant.now());

    // FAILS: hasSize(1) but actually has 2 events!
    assertThat(sprint.getDomainEvents()).hasSize(1);
}
```

### Rule 9: Package Location in entity/

```java
// ✅ CORRECT: Contract tests in entity package
package tw.teddysoft.aiscrum.sprint.entity;

public class SprintContractTest {
    // Tests for Sprint aggregate contracts
}

// ❌ WRONG: In usecase/service package
package tw.teddysoft.aiscrum.sprint.usecase.service;

public class SprintContractTest {  // Wrong location!
```

### Rule 10: Required Imports

```java
// ✅ CORRECT: Complete import list
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;  // For null precondition tests!
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import tw.teddysoft.ucontract.PreconditionViolationException;

// Domain imports
import tw.teddysoft.aiscrum.sprint.entity.*;

// ❌ WRONG: Missing uContract import
// assertThrows(RuntimeException.class, ...)  // Wrong exception type!

// ❌ WRONG: Missing assertThatThrownBy — cannot verify exception message for null preconditions!
// assertThrows(PreconditionViolationException.class, () -> new Product(null, ...));
// ↑ Proves exception thrown, but NOT that message identifies the null field
```

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Verification |
|-------|--------------|
| Aggregate exists | {Aggregate}.java file exists |
| Events exist | {Aggregate}Events.java file exists |
| Contracts identified | require()/ensure() calls found |

### Checkpoint 2: Post-Generation

```bash
# Compile check
cd ${projectRoot} && mvn test-compile -q -pl :${module} 2>&1 | head -20

# Run contract tests
mvn test -Dtest={Aggregate}ContractTest -q

# Verify no Spring annotations
grep -E "@SpringBootTest|@Autowired" ${contractTestFile}
# Should return empty

# Verify all contracts covered
grep -c "@Test" ${contractTestFile}
# Should match number of contracts
```

### Checkpoint 3: Contract Coverage Table

```
Contract Test Coverage for Sprint:
╔══════════════════╦═══════════════╦════════════════════╦════════════╗
║ Method           ║ Contract Type ║ Condition          ║ Test       ║
╠══════════════════╬═══════════════╬════════════════════╬════════════╣
║ start()          ║ Precondition  ║ state == PLANNED   ║ ✅          ║
║ start()          ║ Postcondition ║ state → STARTED    ║ ✅          ║
║ start()          ║ Postcondition ║ SprintStarted      ║ ✅          ║
║ cancel()         ║ Precondition  ║ state != CANCELLED ║ ✅          ║
║ cancel()         ║ Precondition  ║ state != COMPLETED ║ ✅          ║
║ cancel()         ║ Postcondition ║ state → CANCELLED  ║ ✅          ║
║ cancel()         ║ Postcondition ║ reason recorded    ║ ✅          ║
║ cancel()         ║ Postcondition ║ SprintCancelled    ║ ✅          ║
╚══════════════════╩═══════════════╩════════════════════╩════════════╝
Total: 8 tests for 8 contracts ✅
```

---

## GENERATION TEMPLATES

```java
package ${rootPackage}.${aggregateLowerCase}.entity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import tw.teddysoft.ucontract.PreconditionViolationException;

import java.time.Instant;
import java.util.UUID;

/**
 * Contract tests for ${Aggregate} aggregate.
 * These tests verify DBC (Design by Contract) directly on the aggregate:
 * - Preconditions: conditions that must be true before method execution
 * - Postconditions: conditions that must be true after method execution
 * - Invariants: conditions that must always hold
 */
@DisplayName("${Aggregate} Aggregate Contracts")
public class ${Aggregate}ContractTest {

    // ========== Helper Methods ==========

    private ${Aggregate} create${Aggregate}WithState(${Aggregate}State state) {
        return new ${Aggregate}(
                // Required constructor parameters...
                state,
                // Additional parameters...
        );
    }

    private ${Aggregate} create${Aggregate}InState${ValidState}() {
        ${Aggregate} aggregate = create${Aggregate}WithState(${Aggregate}State.${INITIAL_STATE});
        // Apply operations to reach target state
        aggregate.clearDomainEvents();
        return aggregate;
    }

    // ========== Contract Tests ==========

    // ========== Null Precondition Tests (Constructor) ==========
    // MUST use assertThatThrownBy + hasMessageContaining to verify field name in message!

    @Nested
    @DisplayName("Constructor Null Preconditions")
    class ConstructorNullPreconditions {

        @Test
        @DisplayName("constructor rejects null ${fieldName}")
        void constructor_rejects_null_${fieldName}() {
            assertThatThrownBy(() -> new ${Aggregate}(
                    null, /* other valid params... */))
                    .isInstanceOf(PreconditionViolationException.class)
                    .hasMessageContaining("${fieldName}");
        }
    }

    @Nested
    @DisplayName("${methodName}() Contracts")
    class ${MethodName}Contracts {

        // ========== State Precondition Tests ==========

        @Test
        @DisplayName("${methodName}() requires ${validState}")
        void ${methodName}_rejects_${invalidState}() {
            ${Aggregate} aggregate = create${Aggregate}WithState(${Aggregate}State.${INVALID_STATE});

            assertThrows(PreconditionViolationException.class,
                    () -> aggregate.${methodName}(/* parameters */));
        }

        // ========== Postcondition Tests ==========

        @Test
        @DisplayName("${methodName}() ensures ${expectedOutcome}")
        void ${methodName}_ensures_${expectedOutcome}() {
            ${Aggregate} aggregate = create${Aggregate}WithState(${Aggregate}State.${VALID_STATE});

            aggregate.${methodName}(/* parameters */);

            assertThat(aggregate.get${Property}()).isEqualTo(${expectedValue});
        }

        @Test
        @DisplayName("${methodName}() emits ${EventName} event")
        void ${methodName}_emits_${eventName}_event() {
            ${Aggregate} aggregate = create${Aggregate}WithState(${Aggregate}State.${VALID_STATE});

            aggregate.${methodName}(/* parameters */);

            assertThat(aggregate.getDomainEvents())
                .hasSize(1)
                .first()
                .isInstanceOf(${Aggregate}Events.${EventName}.class);
        }

        @Test
        @DisplayName("${methodName}() event contains correct data")
        void ${methodName}_event_contains_correct_data() {
            ${Aggregate} aggregate = create${Aggregate}WithState(${Aggregate}State.${VALID_STATE});

            aggregate.${methodName}(/* parameters */);

            ${Aggregate}Events.${EventName} event = (${Aggregate}Events.${EventName})
                aggregate.getDomainEvents().get(0);
            assertThat(event.${aggregateCamelCase}Id()).isEqualTo(aggregate.getId());
            // Verify other event fields...
        }
    }
}
```

---

## EXAMPLE OUTPUT

### SprintContractTest.java

```java
package tw.teddysoft.aiscrum.sprint.entity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import tw.teddysoft.ucontract.PreconditionViolationException;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.UUID;

@DisplayName("Sprint Aggregate Contracts")
public class SprintContractTest {

    private Sprint createSprintWithState(SprintState state) {
        return new Sprint(
                ProductId.valueOf(UUID.randomUUID().toString()),
                SprintId.valueOf(UUID.randomUUID().toString()),
                SprintName.valueOf("Test Sprint"),
                null,
                Timebox.of(LocalDateTime.now().plusDays(1),
                           LocalDateTime.now().plusDays(15),
                           ZoneId.of("Asia/Taipei")),
                state,
                null, null, null, null,
                null, "scrum-master-1", null
        );
    }

    @Nested
    @DisplayName("start() Contracts")
    class StartContracts {

        @Test
        @DisplayName("start() requires PLANNED state")
        void start_rejects_non_planned_state() {
            Sprint sprint = createSprintWithState(SprintState.STARTED);

            assertThrows(PreconditionViolationException.class,
                    () -> sprint.start("scrum-master-1"));
        }

        @Test
        @DisplayName("start() ensures state becomes STARTED")
        void start_ensures_state_is_STARTED() {
            Sprint sprint = createSprintWithState(SprintState.PLANNED);

            sprint.start("scrum-master-1");

            assertThat(sprint.getState()).isEqualTo(SprintState.STARTED);
        }

        @Test
        @DisplayName("start() emits SprintStarted event")
        void start_emits_SprintStarted_event() {
            Sprint sprint = createSprintWithState(SprintState.PLANNED);

            sprint.start("scrum-master-1");

            assertThat(sprint.getDomainEvents())
                .hasSize(1)
                .first()
                .isInstanceOf(SprintEvents.SprintStarted.class);
        }

        @Test
        @DisplayName("start() event contains correct data")
        void start_event_contains_correct_data() {
            Sprint sprint = createSprintWithState(SprintState.PLANNED);

            sprint.start("scrum-master-1");

            SprintEvents.SprintStarted event = (SprintEvents.SprintStarted)
                sprint.getDomainEvents().get(0);
            assertThat(event.sprintId()).isEqualTo(sprint.getId());
            assertThat(event.metadata().userId()).isEqualTo("scrum-master-1");
        }
    }

    @Nested
    @DisplayName("cancel() Contracts")
    class CancelContracts {

        @Test
        @DisplayName("cancel() rejects already CANCELLED sprint")
        void cancel_rejects_already_cancelled() {
            Sprint sprint = createSprintWithState(SprintState.CANCELLED);

            assertThrows(PreconditionViolationException.class,
                    () -> sprint.cancel("reason", "scrum-master-1"));
        }

        @Test
        @DisplayName("cancel() ensures state becomes CANCELLED")
        void cancel_ensures_state_is_CANCELLED() {
            Sprint sprint = createSprintWithState(SprintState.PLANNED);

            sprint.cancel("Sprint cancelled due to priority change", "scrum-master-1");

            assertThat(sprint.getState()).isEqualTo(SprintState.CANCELLED);
        }

        @Test
        @DisplayName("cancel() ensures reason is recorded")
        void cancel_ensures_reason_recorded() {
            Sprint sprint = createSprintWithState(SprintState.PLANNED);

            sprint.cancel("Budget constraints", "scrum-master-1");

            assertThat(sprint.getCancellationReason()).isEqualTo("Budget constraints");
        }
    }
}
```

---

## SPECIAL CASES

### Soft Delete Verification

```java
@Nested
@DisplayName("markAsDeleted() Contracts")
class MarkAsDeletedContracts {

    @Test
    @DisplayName("markAsDeleted() rejects already deleted aggregate")
    void markAsDeleted_rejects_already_deleted() {
        ${Aggregate} aggregate = create${Aggregate}();
        aggregate.markAsDeleted("user-1");
        aggregate.clearDomainEvents();

        assertThrows(PreconditionViolationException.class,
                () -> aggregate.markAsDeleted("user-1"));
    }

    @Test
    @DisplayName("markAsDeleted() ensures isDeleted is true")
    void markAsDeleted_ensures_isDeleted_is_true() {
        ${Aggregate} aggregate = create${Aggregate}();

        aggregate.markAsDeleted("user-1");

        assertThat(aggregate.isDeleted()).isTrue();
    }
}
```

### Collection Operation Verification

```java
@Nested
@DisplayName("addChild() Contracts")
class AddChildContracts {

    @Test
    @DisplayName("addChild() ensures child is in children list")
    void addChild_ensures_child_in_list() {
        Workflow workflow = createWorkflow();
        Lane parent = workflow.getRootStages().get(0);
        LaneId childId = LaneId.valueOf(UUID.randomUUID().toString());

        workflow.addChild(parent.getId(), childId, "SubStage", LaneType.STAGE, 0, "user-1");

        assertThat(workflow.getLaneById(childId)).isPresent();
        assertThat(parent.getChildren()).anyMatch(c -> c.getId().equals(childId));
    }

    @Test
    @DisplayName("addChild() ensures children are ordered")
    void addChild_ensures_children_ordered() {
        Workflow workflow = createWorkflow();
        Lane parent = workflow.getRootStages().get(0);

        workflow.addChild(parent.getId(), LaneId.create(), "Child-A", LaneType.STAGE, 0, "user-1");
        workflow.addChild(parent.getId(), LaneId.create(), "Child-B", LaneType.STAGE, 1, "user-1");

        List<Lane> children = parent.getChildren();
        assertThat(children).hasSize(2);
        assertThat(children.get(0).getOrder()).isEqualTo(0);
        assertThat(children.get(1).getOrder()).isEqualTo(1);
    }
}
```

### Class Invariant Verification

```java
@Nested
@DisplayName("Class Invariants")
class ClassInvariants {

    @Test
    @DisplayName("INV-1: Name is never null after any operation")
    void invariant_name_never_null() {
        Workflow workflow = createWorkflow();

        // Exercise multiple operations
        workflow.rename("New Name", "user-1");
        workflow.changeNote("Some note", "user-1");

        // Invariant must hold
        assertThat(workflow.getName()).isNotNull();
        assertThat(workflow.getName().value()).isNotBlank();
    }

    @Test
    @DisplayName("INV-2: Deleted aggregate rejects all modifications")
    void invariant_deleted_rejects_modifications() {
        Workflow workflow = createWorkflow();
        workflow.markAsDeleted("user-1");

        // All modification operations should fail
        assertThrows(PreconditionViolationException.class,
                () -> workflow.rename("New Name", "user-1"));
        assertThrows(PreconditionViolationException.class,
                () -> workflow.changeNote("New Note", "user-1"));
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.7: Invoke contract-test-skill
    ├─ Input: {Aggregate}.java, {Aggregate}Events.java
    ├─ Output: {Aggregate}ContractTest.java
    └─ Next: usecase-test-skill (Step 4.8)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Missing PreconditionViolationException import | Add `import tw.teddysoft.ucontract.PreconditionViolationException` |
| Tests fail with wrong exception | Verify aggregate uses `require()` not manual throws |
| Event verification fails | Check clearDomainEvents() in helper methods |
| @SpringBootTest found | Remove - contract tests don't need Spring |
| Tests in wrong package | Move to `entity/` package |
| Missing @Nested class | Create @Nested for each command method |

---
