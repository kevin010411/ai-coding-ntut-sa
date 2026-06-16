# Mutation Tester (ezddd-java)

## Overview

使用 PIT 提升 mutation coverage 的完整工具：
- **PIT Mutation Testing** - 識別存活 mutants
- **uContract (Design by Contract)** - 契約驗證，非防禦性程式設計
- **Assertion-free Tests** - 依賴契約驗證

## File Structure

```
references/mutation-tester/
├── README.md                  ← 本檔案
├── workflow.md                ← 執行流程 (Phase 1-6)
├── rules.md                   ← 必遵守規則 + ignore() 模式
└── strategies.md              ← 策略指南 + Parallel Mode
```

## Execution Modes

| Mode | Command | Threshold | TRUE_RETURNS | Use Case |
|------|---------|-----------|--------------|----------|
| **Default** | `mutation-tester Entity` | 75% | Excluded | DBC design, accept postcondition survivors |
| **Spy Mode** | `mutation-tester Entity --spy` | 85% | Included | Generate spy tests to kill all mutants |
| **Parallel Mode** | `mutation-tester --parallel E1,E2,...` | 75% | Excluded | Test multiple aggregates simultaneously |

### Why Two Modes?

Postcondition lambdas in `ensure()` always survive `BooleanTrueReturnValsMutator`:
- `ensure("...", () -> someCheck())` mutated to `ensure("...", () -> true)` passes silently
- This is a known limitation of uContract + PIT

**Default Mode**: Accepts this limitation, excludes TRUE_RETURNS mutator
**Spy Mode**: Generates spy tests to verify postcondition methods are actually called

## Usage

```bash
# Default mode (75% threshold)
/mutation-test Product

# Spy mode (85% threshold, generates spy tests)
/mutation-test Sprint --spy

# Parallel mode (multiple aggregates)
/mutation-test --parallel Product,Sprint,Workflow

# Auto-discover all aggregates
/mutation-test --parallel all
```

## Trigger Conditions

Automatically activate when user mentions:
- "mutation testing" / "mutation coverage"
- "improve test quality" / "increase coverage"
- "add contracts" / "Design by Contract"
- "PIT testing" / "kill mutants"

## Core Philosophy

| Principle | Description |
|-----------|-------------|
| **uContract** | Design by Contract - 行為規格，非防禦性程式設計 |
| **Assertion-free** | 依賴契約驗證正確性 |
| **Incremental** | 永不破壞現有測試 |
| **Postconditions First** | 最安全的契約類型優先 |

## Test Selection Strategy

### 必須使用 Use Case Tests

針對 `<Aggregate>` 執行 mutation testing 時，**必須**使用該 Aggregate 的所有 Use Case tests：

```bash
mvn org.pitest:pitest-maven:mutationCoverage \
    -DtargetClasses=tw.teddysoft.aiscrum.<aggregate>.entity.<Aggregate> \
    -DtargetTests=tw.teddysoft.aiscrum.<aggregate>.usecase.service.*Test -q
```

### 為什麼不能只用 Contract Tests？

| 測試類型 | 覆蓋範圍 | Mutation Testing 效果 |
|---------|---------|----------------------|
| **Contract Tests** | 只測 precondition violations | ❌ 低 - 不觸發 postconditions |
| **Use Case Tests** | 測試完整業務流程 | ✅ **高** - 觸發所有 contracts |

## Quick Commands

```bash
# Run PIT for specific aggregate
mvn org.pitest:pitest-maven:mutationCoverage \
    -DtargetClasses=tw.teddysoft.aiscrum.pbi.entity.ProductBacklogItem \
    -DtargetTests=tw.teddysoft.aiscrum.pbi.usecase.service.*Test -q

# Find existing contracts
grep -rn "require\|ensure\|invariant" src/main/java/

# Check mutation report
open target/pit-reports/*/index.html

# Auto-discover all aggregates
find src/main/java -path "*/entity/*.java" -name "*.java" \
  ! -name "*Id.java" ! -name "*Events.java" ! -name "*State.java" \
  -exec basename {} .java \; | sort -u
```

## Target Metrics

### Default Mode (no --spy)

| Metric | Target |
|--------|--------|
| Mutation Coverage | > 75% |
| Test Strength | > 80% |
| Existing Tests Pass | 100% |

### Spy Mode (--spy)

| Metric | Target |
|--------|--------|
| Mutation Coverage | > 85% |
| Test Strength | > 90% |
| Existing Tests Pass | 100% |
| Spy Tests Generated | All POST-EXEC |

## Success Criteria

### Default Mode

1. All existing tests still pass (100%)
2. Mutation coverage > 75% (with TRUE_RETURNS excluded)
3. Test strength > 80%
4. No behavior changes introduced

### Spy Mode

1. All existing tests still pass (100%)
2. Mutation coverage > 85% (with TRUE_RETURNS included)
3. All postcondition lambdas have spy tests
4. Spy tests follow naming convention

### Parallel Mode

1. All aggregates complete PIT execution
2. Consolidated report generated
3. Average mutation coverage > 75%
4. Execution time reduced vs sequential (40-60% savings)
