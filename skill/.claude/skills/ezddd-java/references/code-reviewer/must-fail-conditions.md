# Must Fail Conditions

If any of these are found, the review **MUST FAIL**.

## Event Sourcing Violations (CRITICAL)

| # | Condition | Severity |
|---|-----------|----------|
| 1 | Constructor sets state directly (instead of via apply/when) | CRITICAL |
| 2 | State modification outside `when()` method | CRITICAL |
| 3 | Missing `apply(event)` calls in command methods | CRITICAL |
| 4 | Static factory methods in Aggregates (use public constructor) | CRITICAL |

## Domain Event Issues (CRITICAL)

| # | Condition | Severity |
|---|-----------|----------|
| 5 | Self-defined ConstructionEvent/DestructionEvent interface (must use `InternalDomainEvent.XXX`) | CRITICAL |
| 6 | Domain Event without `metadata` field or `metadata()` method | CRITICAL |
| 7 | Domain Event using `Map.of()` for metadata (must use `new HashMap<>()`) | CRITICAL |
| 8 | Missing `static mapper()` method (ADR-047 Auto-Registration) | MUST FIX |

## Annotation Violations (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 9 | `@Service` or `@Component` on UseCase Services (must use `@Bean`) | MUST FIX |
| 10 | `@ActiveProfiles` on BaseUseCaseTest (violates ADR-021) | MUST FIX |
| 11 | Missing `@Transient` on OutboxData fields | MUST FIX |
| 12 | `@Enumerated` on String fields in Data Class | MUST FIX |

## Package & Import Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 13 | `javax.persistence` (must use `jakarta.persistence`) | MUST FIX |
| 14 | Mapper in wrong package (`adapter/out/mapper/` instead of `usecase/port/`) | MUST FIX |
| 15 | Contract Test in wrong package (must be in `entity/`, not `usecase/service/`) | MUST FIX |

## Repository Violations (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 16 | Custom Repository interfaces (must use generic `Repository<T, ID>`) | MUST FIX |
| 17 | Empty Repository inheritance class (redundant) | SHOULD FIX |
| 18 | Repository with extra query methods (must use Projection) | MUST FIX |

## Entity/Value Object Violations (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 19 | Entity using `Contract.requireNotNull()` (must use `Objects.requireNonNull()`) | MUST FIX |
| 20 | Entity not implementing `Entity<ID>` interface | MUST FIX |
| 21 | Entity missing `equals/hashCode` based on ID | MUST FIX |
| 22 | Value Object using `Contract.requireNotNull()` (must use `Objects.requireNonNull()`) | MUST FIX |
| 23 | Value Object (record/class) not implementing `ValueObject` interface (**enum is EXEMPT**) | MUST FIX |
| 24 | Value Object with setter methods (must be immutable) | MUST FIX |

## Data Class Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 25 | Enum type fields in Data Class (must use String) | MUST FIX |
| 26 | Standalone OutboxMapper class (must be inner class) | MUST FIX |

## Contract Test Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 27 | Contract Test using Spring annotations (`@SpringBootTest`, `@Autowired`, etc.) | MUST FIX |
| 28 | Contract Test not using `assertThrows(PreconditionViolationException.class, ...)` | MUST FIX |
| 29 | Contract Test missing `@Nested` class for command method with preconditions | SHOULD FIX |
| 30 | Contract Test missing `create{Aggregate}WithState()` helper method | SHOULD FIX |

## Mapper Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 31 | Mapper without `JavaTimeModule` in ObjectMapper | MUST FIX |
| 32 | Mapper with asymmetric `toData/toDomain` (missing field conversion) | MUST FIX |

## Semantics Violations (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 33 | `value_immutable` field has setter or mutating event | MUST FIX |
| 34 | `collection_reference_immutable` has `setXxx(List)` method | MUST FIX |

## Postcondition Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 35 | Domain Event postcondition only checks event existence without verifying aggregate ID field (e.g., `productId`) and business fields | MUST FIX |

## Idempotency Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 36 | Idempotent operation using implicit return without `ignore()` | MUST FIX |

## Test Issues (MUST FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 37 | Missing global `InMemoryTestSuite`/`OutboxTestSuite` when `dualProfileSupport=true` | MUST FIX |
| 38 | `@SelectClasses` contains test classes instead of only `ProfileSetter` (should use `@SelectPackages`) | MUST FIX |
| 38b | Per-use-case TestSuite exists (e.g., `InMemoryCreateProductTestSuite`) instead of global suite | MUST FIX |
| 39 | Tests not passing | CRITICAL |

## Code Quality Issues (SHOULD FIX)

| # | Condition | Severity |
|---|-----------|----------|
| 40 | Comments in code (unless explicitly requested) | SHOULD FIX |
| 41 | `System.out.println` or debug logging | SHOULD FIX |

---

## Summary by Severity

| Severity | Count | Action |
|----------|-------|--------|
| **CRITICAL** | 8 | Must fix immediately, blocks approval |
| **MUST FIX** | 29 | Must fix before merge |
| **SHOULD FIX** | 5 | Recommended to fix |

## Rating Impact

| Issues Found | Rating |
|--------------|--------|
| Any CRITICAL | 1 star (REJECTED) |
| Multiple MUST FIX | 2 stars |
| Few MUST FIX | 3 stars |
| Only SHOULD FIX | 4 stars |
| No issues | 5 stars |
