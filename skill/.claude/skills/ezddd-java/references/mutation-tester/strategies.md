# Mutation Testing Strategies (ezddd-java)

## Overview

Use PIT (Pitest) to improve mutation test coverage by:
1. Identifying surviving mutants
2. Generating tests to kill them
3. Verifying contract completeness

## Execution Command

```bash
# Run PIT for specific aggregate
SPRING_PROFILES_ACTIVE=test-inmemory mvn \
  org.pitest:pitest-maven:mutationCoverage \
  -DtargetClasses="{package}.{aggregate}.entity.{Aggregate}" \
  -DtargetTests="{package}.{aggregate}.**" \
  -DmutationThreshold=75
```

## Common Surviving Mutant Types

### 1. Boundary Condition Mutants

**Symptom**: Operators like `<`, `>`, `<=`, `>=` mutated

**Strategy**: Add boundary tests

```java
// Original
if (quantity > 0) { ... }

// Mutant survives: quantity >= 0
// Add test:
@Test
void should_reject_zero_quantity() {
    // Test boundary condition
}
```

### 2. Return Value Mutants

**Symptom**: Return values changed

**Strategy**: Assert return values explicitly

```java
// Add postcondition verification
then("returns correct value", () -> {
    assertThat(result).isEqualTo(expectedValue);
});
```

### 3. Conditional Mutants

**Symptom**: Conditions negated or removed

**Strategy**: Test both branches

```java
// Test true branch
@Test void should_handle_when_condition_true() { }

// Test false branch
@Test void should_handle_when_condition_false() { }
```

### 4. Contract Lambda Mutants

**Symptom**: Contract checks bypassed

**Strategy**: Use underscore-prefix helpers (excluded from PIT)

```java
// Helper excluded from PIT via pom.xml <excludedMethods>_*</excludedMethods>
private boolean _isValidState() {
    return this.state != State.DELETED;
}

public void doSomething() {
    require("Valid state", () -> _isValidState());
}
```

## Spy Test Pattern

For postcondition mutants that survive:

```java
@Test
void should_verify_postcondition_after_operation() {
    // Arrange
    Product product = new Product(...);

    // Act
    product.rename("New Name", "user1");

    // Assert - Spy on internal state
    assertThat(product.getName()).isEqualTo("New Name");
    assertThat(product.getVersion()).isEqualTo(1);
}
```

## Coverage Thresholds

| Level | Threshold | Action |
|-------|-----------|--------|
| Acceptable | >= 75% | Pass |
| Warning | 60-74% | Review surviving mutants |
| Failing | < 60% | Must add tests |

## Quick Reference（簡化流程，完整 6-Phase 流程見 `workflow.md`）

### Step 1: Run Initial Analysis

```bash
mvn pitest:mutationCoverage -DtargetClasses=...
```

### Step 2: Review Report

Open `target/pit-reports/*/index.html`

### Step 3: Identify Patterns

Common surviving mutant patterns:
- Unchecked edge cases
- Missing postcondition assertions
- Conditional branch not tested

### Step 4: Generate Killing Tests

For each surviving mutant:
1. Understand what the mutant changes
2. Write a test that would fail with the mutant
3. Verify the test kills the mutant

### Step 5: Re-run Analysis

Verify mutation coverage improved.

## POM Configuration

```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.15.0</version>
    <configuration>
        <excludedMethods>
            <!-- Exclude contract helpers from mutation -->
            <param>_*</param>
        </excludedMethods>
        <mutationThreshold>75</mutationThreshold>
    </configuration>
</plugin>
```

## Contract Test Integration

### Class Invariant Rule

- INV tests only need to run once per aggregate
- If `rename()` tests INV-1, `changeNote()` doesn't need to

### Precondition/Postcondition

- Each method needs its own PRE/POST tests
- Different methods have different contracts

## Report Template

```markdown
## Mutation Test Report: {Aggregate}

### Summary
- **Total Mutants**: X
- **Killed**: Y
- **Survived**: Z
- **Coverage**: XX%

### Surviving Mutants

| # | Location | Mutant Type | Strategy |
|---|----------|-------------|----------|
| 1 | Line 42 | Boundary | Add edge case test |
| 2 | Line 78 | Return Value | Add assertion |

### Generated Tests

1. `test_boundary_case_for_quantity()`
2. `test_return_value_after_operation()`

### New Coverage: XX% -> YY%
```
