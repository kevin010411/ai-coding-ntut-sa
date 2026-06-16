# Common Rules for ezddd-java

## ABSOLUTELY FORBIDDEN

1. **NEVER add comments** in generated code (unless explicitly requested). `references/examples/` 下的範例檔案為教學用途，可包含解說性註解
2. **NEVER add System.out.println** in generated code. Test infrastructure（`BaseUseCaseTest`、`ProfileSetter`）的 profile/cleanup 診斷輸出除外
3. **NEVER use @Component or @Service** on Service classes - use @Bean
4. **NEVER hardcode Spring profiles** - use environment variables
5. **NEVER use javax.persistence** - always use jakarta.persistence
6. **NEVER add @ActiveProfiles** to test classes
7. **NEVER modify frontend code when fixing API consistency issues** - API 一致性檢查發現不一致時，只能修改後端 Controller，不可修改前端程式碼（`frontend/`），除非明確與使用者確認同意

## ALWAYS REQUIRED

1. **ALWAYS use `requireNotNull()`** (via `import static tw.teddysoft.ucontract.Contract.*`) for DBC contract checks — used in Aggregate Root AND UseCase Service execute() methods for preconditions。UseCase Service 建構子、Entity、Value Object、Domain Event、Mapper 使用 `Objects.requireNonNull()`（簡單 null check，非 DBC）
2. **ALWAYS use Value Object factory methods** — ID 型別：`ProductId.valueOf(String)`, `ProductId.valueOf(UUID)`, `ProductId.create()`；非 ID 型別：`Name.valueOf(String)`, `Name.valueOf(UUID)` — external code should not call `new ProductId()` directly
3. **ALWAYS return CqrsOutput** for commands, DTOs for queries
4. **ALWAYS use blanket catch pattern** — 業務錯誤（not found, already exists）透過 `CqrsOutput` + `ExitCode.FAILURE` 回傳；非預期例外由 blanket `catch (Exception e)` 捕捉並 wrap 在 `UseCaseFailureException` 中。詳見 `patterns/usecase/command.md` Rule 9
5. **ALWAYS register Service as @Bean** in Configuration classes
6. **ALWAYS use `ignore()` for idempotency**

## DateProvider Usage (CRITICAL)

**MUST use `DateProvider.now()` instead of `Instant.now()` when creating Domain Events:**

```java
// CORRECT
apply(new ProductCreated(
    productId, name, new HashMap<>(),
    UUID.randomUUID(),
    DateProvider.now()    // Enables deterministic testing
));

// WRONG
apply(new ProductCreated(
    productId, name, new HashMap<>(),
    UUID.randomUUID(),
    Instant.now()         // Cannot control in tests!
));
```

**Why DateProvider?**
- Test Determinism: Tests can use `DateProvider.useFixedInstant(...)` to control time
- Reproducibility: Same test input produces same output
- Verification: Can assert exact `occurredOn` values

## uContract Idempotency Pattern: ignore()

```java
// CORRECT: Use ignore() for idempotency
public void changeState(State newState, String userId) {
    if (ignore("State unchanged - idempotent no-op", () -> this.state == newState)) return;
    // State change only happens when necessary
    ...
}

// WRONG: Plain if-check without semantic meaning
if (this.state == newState) {
    return;
}
```

## Cross-Aggregate Value Object Rules (CRITICAL)

**Principle**: Value Object defined once, import across aggregates.

### Step 1: Search First (MANDATORY)

```bash
# Before generating any VO, search if it exists
Glob: **/entity/{ValueObjectName}.java
```

- **Exists** → `import` it, don't redefine
- **Not exists** → Go to Step 2

### Step 2: Ownership Rules

| Case | Judgment | Location |
|------|----------|----------|
| `external` annotation | Spec explicitly specifies source | `import {external}.entity.XxxId` |
| `XxxId` format | Infer from aggregate.yaml | See naming rules |
| Common VO | Name in common list | `common/entity/` |
| Other | Cannot determine | Current aggregate |

### XxxId Naming Convention

```yaml
# Current aggregate's aggregate.yaml
name: Workflow          # Aggregate Root
entities:               # Internal Entities
  - name: Lane
  - name: Stage
```

| `XxxId` Type | Judgment | Action |
|--------------|----------|--------|
| `Xxx` = current aggregate | Belongs to current | Define in `{aggregate}/entity/` |
| `Xxx` ∈ entities | Belongs to current | Define in `{aggregate}/entity/` |
| `Xxx` ≠ above | Belongs to other | `import {xxx}.entity.XxxId` |

### Common Value Object List

```
Money, Currency, Email, Phone, Address,
DateRange, TimeRange, Percentage, Quantity,
UserId, TenantId
```

## Security Rules

<!-- @authority: no_hardcoded_secrets | source: rules/security-patterns.md -->
<!-- @authority: cors_centralized_config | source: rules/security-patterns.md -->

8. **NEVER hardcode passwords/secrets in Java source** — use `@Value("${ENV_VAR}")` or Spring Environment. Properties files should use placeholders `${DB_PASSWORD:root}` (see `security-patterns.md` Rules 1-3)
9. **NEVER commit secret files** — `.gitignore` must include `.env`, `*.key`, `*.pem`, `credentials.json` (see `security-patterns.md` Rule 2)

## Configuration Generation Rules

**Before generating ANY properties/yaml configuration file:**

1. **MUST read `.dev/project-config.json` FIRST**
2. **MUST use template files** from `references/templates/` and `references/init-project/`
3. **MUST extract values from project-config.json**
4. **NEVER guess or assume configuration values**
