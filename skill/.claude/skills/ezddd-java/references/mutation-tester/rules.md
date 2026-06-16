# Mutation Tester Rules

## Critical Rules

### Absolutely Forbidden

| Rule | Description |
|------|-------------|
| No comments | Unless explicitly requested |
| No breaking tests | Maintain 100% backward compatibility |
| No `reject()` | 已廢棄，使用 `ignore()` 實現冪等性 |
| No behavior changes | Only add postconditions and invariants |
| No `System.out.println` | No debug output |
| No skipping verification | Always run PIT after changes |
| No assertions in AF tests | Keep assertion-free tests truly assertion-free |

### Always Required

| Rule | Description |
|------|-------------|
| Run existing tests first | Before making any changes |
| Add postconditions first | Safer than preconditions |
| Use `ignore()` for idempotency | 取代傳統 early return |
| Verify improvement | Run PIT after changes |
| Keep AF tests clean | No assertions in assertion-free tests |
| Test incrementally | One contract at a time |
| Rollback on failure | Maintain stability |

---

## 冪等性處理：ignore() 模式

uContract 的 `ignore()` 回傳 boolean，搭配 `if/return` 實現冪等性操作：

```java
// ✅ uContract 冪等性模式
public void changeState(State newState, String userId) {
    if (ignore("State unchanged - idempotent no-op", () -> this.state == newState)) return;
    // 以下只有狀態改變時才執行
    ...
}

// ❌ 缺少描述字串，語意不明確
public void changeState(State newState, String userId) {
    if (this.state == newState) {
        return;  // 隱含的 no-op
    }
    ...
}
```

**優點**：
- 語意清晰
- 契約風格統一
- 可追蹤（有描述字串）

---

## Contract Patterns

### Correct Pattern: Postcondition

```java
public void createTask(TaskId taskId, String name, String creatorId) {
    requireNotNull("taskId", taskId);
    requireNotNull("name", name);

    // Business logic
    Task task = new Task(taskId, name);
    this.tasks.add(task);

    apply(new TaskCreated(...));

    // Postcondition - verify the result
    ensure("Task is in the task list", () ->
        tasks.stream().anyMatch(t -> t.getId().equals(taskId))
    );

    ensure("Task has correct name", () ->
        getTask(taskId).map(t -> t.getName().equals(name)).orElse(false)
    );
}
```

### Correct Pattern: Invariant

```java
public class ProductBacklogItem extends EsAggregateRoot<...> {

    // Called after every state change
    private void checkInvariants() {
        invariant("Tasks collection is never null", () ->
            this.tasks != null
        );

        invariant("Selected PBI must have sprint", () ->
            this.state != PbiState.SELECTED || this.sprintId != null
        );
    }
}
```

### Wrong Pattern: Over-restrictive Precondition

```java
// ❌ WRONG - Changes existing behavior
require("Must be in specific state", () ->
    state == PbiState.SELECTED || state == PbiState.IN_PROGRESS
);

// ✅ CORRECT - Only validates what's already required
require("Name cannot be empty", () ->
    !name.trim().isEmpty()
);
```

---

## Contract Helper Pattern

所有 `require/ensure/invariant` lambda 必須委派給底線開頭的 helper 方法：

```java
// ✅ Correct: Lambda delegates to _helper
ensure("Sprint is committed", () -> _isSprintCommitted(sprintId));

private boolean _isSprintCommitted(SprintId sprintId) {
    return this.committedSprints.contains(sprintId);
}
```

**為什麼使用底線前綴？**

1. **PIT Exclusion**: `pom.xml` 的 `<excludedMethods>_*</excludedMethods>` 排除這些 helper
2. **避免 False Positives**: Contract logic 被 mutate 不代表測試缺失
3. **命名慣例**: 清楚標示這是契約用 helper

---

## POM Configuration

```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <configuration>
        <avoidCallsTo>
            <avoidCallsTo>tw.teddysoft.ucontract.Contract</avoidCallsTo>
            <avoidCallsTo>tw.teddysoft.ucontract</avoidCallsTo>
        </avoidCallsTo>
        <excludedMethods>
            <!-- Exclude contract helpers from mutation -->
            <param>_*</param>
        </excludedMethods>
        <targetClasses>
            <param>tw.teddysoft.aiscrum.*.entity.*</param>
        </targetClasses>
        <targetTests>
            <param>tw.teddysoft.aiscrum.*.usecase.*Test</param>
            <param>tw.teddysoft.aiscrum.*.entity.*Test</param>
        </targetTests>
    </configuration>
</plugin>
```

---

## Contract Test Judgment Rules

### Test Strategy by Contract Type

| 契約類型 | 縮寫 | 測試策略 |
|---------|------|---------|
| **Precondition** | PRE-N | 每個方法各自測試 |
| **Postcondition** | POST-N | 每個方法各自測試 |
| **Getter Contract** | GC-N | 每個 getter 各自測試 |
| **Class Invariant** | INV-N | **只需測一次**（aggregate 層級共用） |

### Class Invariant Special Rule

- uContract 框架會在**每個 public 方法入口**自動呼叫 `ensureInvariant()`
- 如果任一操作（如 `rename()`）已測試某個 INV，**其他操作不需重複測試**

```
❌ 錯誤判斷：「rename() 有測 INV-1，但 changeNote() 沒測 → GAP」
✅ 正確判斷：「INV-1 是 aggregate-level invariant，rename() 已測 → 不是 GAP」
```

---

## Coverage Thresholds

| Level | Threshold | Action |
|-------|-----------|--------|
| Acceptable | >= 75% | Pass |
| Warning | 60-74% | Review surviving mutants |
| Failing | < 60% | Must add tests |

---

## Failure Conditions

Mutation testing is considered **FAILED** if:

1. **Existing Tests Broken** - Any test that passed before now fails
2. **Coverage Below Threshold** - Mutation coverage < 75% (default) or < 85% (spy mode)
3. **Behavior Changed** - Contracts change existing method semantics
4. **No Rollback on Failure** - Failed changes not reverted
5. **Skipped Verification** - PIT not run after contract additions
