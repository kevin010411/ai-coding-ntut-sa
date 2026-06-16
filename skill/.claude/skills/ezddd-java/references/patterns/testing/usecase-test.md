# Use Case Test Generation Skill

## Overview

This skill generates Use Case Tests using ezSpec BDD framework with Spring integration.
Tests verify Acceptance Criteria (AC) using Given-When-Then syntax.

Key differences from Contract Tests:
- **Contract Tests**: Pure JUnit 5, verify DBC on Aggregate
- **Use Case Tests**: Spring + ezSpec, verify AC on Service layer

---

## INPUT

| Source | Path |
|--------|------|
| Use Case Interface | `src/main/java/{rootPackage}/{aggregate}/usecase/port/in/{UseCase}UseCase.java` |
| Use Case Service | `src/main/java/{rootPackage}/{aggregate}/usecase/service/{UseCase}Service.java` |
| Acceptance Criteria | `JSON spec `testScenarios[]`` |
| project-config.json | `.dev/project-config.json` (check dualProfileSupport) |

---

## OUTPUT

| File | Location |
|------|----------|
| Test Class | `src/test/java/{rootPackage}/{aggregate}/usecase/service/{UseCase}ServiceTest.java` |

> **Note**: TestSuite 是全域的（`InMemoryTestSuite` + `OutboxTestSuite`），不是 per-use-case 產生。
> 第一次 PF 執行時建立，後續只需確認 `@SelectPackages` 包含該 aggregate 的 package。
> 模板：`references/templates/test-suites.md`

---

## TEST CATEGORIES

### Category 1: Command Use Case Tests

Test Create/Update/Delete operations with event verification.

```java
@EzScenario
public void should_create_product_successfully() {
    Feature.New("Create Product").newScenario()
        .Given("a valid product creation request", env -> {
            String productId = UUID.randomUUID().toString();
            String productName = "Test Product";
            env.put("productId", productId);
            env.put("productName", productName);
            var input = CreateProductUseCase.CreateProductInput.create();
            input.productId = productId;
            input.name = productName;
            input.userId = "user-1";
            env.put("input", input);
        })
        .When("the create product use case is executed", env -> {
            var input = env.get("input", CreateProductUseCase.CreateProductInput.class);
            var output = createProductUseCase.execute(input);
            env.put("output", output);
        })
        .Then("the operation should succeed", env -> {
            var output = env.get("output", CqrsOutput.class);
            assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
            assertThat(output.getId()).isEqualTo(env.gets("productId"));
        })
        .And("the product should be persisted", env -> {
            var productId = ProductId.valueOf(env.gets("productId"));
            var product = productRepository.findById(productId).orElse(null);
            assertThat(product).isNotNull();
            assertThat(product.getName().value()).isEqualTo(env.gets("productName"));
        })
        .And("the ProductCreated event should be published", env -> {
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
                assertThat(notifyFakeHandleAllEventsService.handledEventTimes(
                    ProductEvents.ProductCreated.class)).isEqualTo(1);
            });
        })
        .Execute();
}
```

### Category 2: Query Use Case Tests

Test Read operations with data setup.

```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️ N2: AWAIT-BEFORE-CLEAR PATTERN (Async Event Race)          ║
╠════════════════════════════════════════════════════════════════╣
║  When Given step calls a Command UseCase that produces events, ║
║  you MUST await event delivery BEFORE calling                  ║
║  clearCapturedEvents(). Otherwise the relay hasn't finished    ║
║  yet and events leak into the When/Then assertions.            ║
║                                                                ║
║  ❌ WRONG:                                                      ║
║    createProductUseCase.execute(input);                         ║
║    clearCapturedEvents();  // relay may not have finished!      ║
║                                                                ║
║  ✅ CORRECT:                                                    ║
║    createProductUseCase.execute(input);                         ║
║    await().atMost(5, TimeUnit.SECONDS).untilAsserted(() -> {   ║
║      assertThat(notifyFakeHandleAllEventsService               ║
║        .getHandledEventsSize()).isGreaterThanOrEqualTo(1);      ║
║    });                                                         ║
║    clearCapturedEvents();                                      ║
╚════════════════════════════════════════════════════════════════╝
```

```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️ N4: IDF QUERY TEST — DB CLEANUP FOR OUTBOX PROFILE         ║
╠════════════════════════════════════════════════════════════════╣
║  @DirtiesContext only rebuilds Spring Context, NOT PostgreSQL! ║
║  IDF query tests MUST clean DB data in @BeforeEach:            ║
║                                                                ║
║  @Autowired(required = false) // null in InMemory profile      ║
║  private JdbcTemplate jdbcTemplate;                            ║
║                                                                ║
║  @BeforeEach                                                   ║
║  public void setUp() {                                         ║
║      if (jdbcTemplate != null) {  // Outbox profile only       ║
║          jdbcTemplate.execute("DELETE FROM child_table");       ║
║          jdbcTemplate.execute("DELETE FROM parent_table");      ║
║      }                                                         ║
║      setUpEventCapture();                                      ║
║  }                                                             ║
║                                                                ║
║  ⚠️ FK constraint ordering: DELETE child tables FIRST!          ║
╚════════════════════════════════════════════════════════════════╝
```

```java
@EzScenario
public void should_get_product_by_id() {
    feature.newScenario()
        .Given("a product exists", env -> {
            // Create product through use case first
            String productId = UUID.randomUUID().toString();
            var createInput = CreateProductUseCase.CreateProductInput.create();
            createInput.productId = productId;
            createInput.name = "Test Product";
            createInput.userId = "user-1";
            createProductUseCase.execute(createInput);
            // Await-then-clear: events are async, must confirm arrival before clearing
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                            .isGreaterThanOrEqualTo(1));
            clearCapturedEvents();
            env.put("productId", productId);
        })
        .When("the get product use case is executed", env -> {
            var input = GetProductUseCase.GetProductInput.create();
            input.productId = env.gets("productId");
            var output = getProductUseCase.execute(input);
            env.put("output", output);
        })
        .Then("the operation should succeed", env -> {
            var output = env.get("output", GetProductUseCase.Output.class);
            assertThat(output.exitCode()).isEqualTo(ExitCode.SUCCESS);
        })
        .And("the product data should be returned", env -> {
            var output = env.get("output", GetProductUseCase.Output.class);
            assertThat(output.productDto().id()).isEqualTo(env.gets("productId"));
            assertThat(output.productDto().name()).isEqualTo("Test Product");
        })
        .Execute();
}
```

### Category 3: Error Handling Tests

Test failure scenarios with error verification.

```java
@EzScenario
public void should_reject_duplicate_product_name() {
    feature.newScenario()
        .Given("a product with name 'Existing Product' exists", env -> {
            var createInput = CreateProductUseCase.CreateProductInput.create();
            createInput.productId = UUID.randomUUID().toString();
            createInput.name = "Existing Product";
            createInput.userId = "user-1";
            createProductUseCase.execute(createInput);
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                            .isGreaterThanOrEqualTo(1));
            clearCapturedEvents();
        })
        .When("creating another product with same name", env -> {
            var productId = UUID.randomUUID().toString();
            env.put("productId", productId);
            var input = CreateProductUseCase.CreateProductInput.create();
            input.productId = productId;
            input.name = "Existing Product";
            input.userId = "user-1";
            try {
                var output = createProductUseCase.execute(input);
                env.put("output", output);
                env.put("exceptionThrown", false);
            } catch (Exception e) {
                env.put("exception", e);
                env.put("exceptionThrown", true);
            }
        })
        .Then("the operation should fail", env -> {
            if (env.get("exceptionThrown", Boolean.class)) {
                var exception = env.get("exception", Exception.class);
                assertThat(exception).isInstanceOf(PreconditionViolationException.class);
            } else {
                var output = env.get("output", CqrsOutput.class);
                assertThat(output.getExitCode()).isEqualTo(ExitCode.FAILURE);
            }
        })
        .And("no duplicate product should be persisted", env -> {
            var productId = ProductId.valueOf(env.gets("productId"));
            assertThat(productRepository.findById(productId)).isEmpty();
        })
        .And("no domain events should be published", env -> {
            long eventCountAfter = notifyFakeHandleAllEventsService.getHandledEventsSize();
            assertThat(eventCountAfter).isEqualTo(0);
        })
        .Execute();
}
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: NO @ActiveProfiles (ADR-021)

```java
// ✅ CORRECT: No profile annotation
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {
}

// ❌ WRONG: @ActiveProfiles breaks dual-profile support
@SpringBootTest
@ActiveProfiles("test-inmemory")  // FORBIDDEN!
public class CreateProductServiceTest extends BaseUseCaseTest {
}
```

**Rationale:** Profile is controlled by environment variable or TestSuite, not by annotation.

### Rule 2: Extend BaseUseCaseTest and Call setUpEventCapture/tearDownEventCapture

```java
// ✅ CORRECT: Extend BaseUseCaseTest + manually call setUpEventCapture/tearDownEventCapture
public class CreateProductServiceTest extends BaseUseCaseTest {

    @BeforeEach
    public void setUp() {
        setUpEventCapture();    // MUST call — protected, not auto-invoked
        DateProvider.useSystemTime();
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture(); // MUST call — protected, not auto-invoked
    }
}

// ❌ WRONG: Not extending BaseUseCaseTest
public class CreateProductServiceTest {  // Missing BaseUseCaseTest!
    // No event capture infrastructure
}

// ❌ WRONG: Forgetting to call setUpEventCapture
public class CreateProductServiceTest extends BaseUseCaseTest {
    @BeforeEach
    void setUp() {
        DateProvider.useSystemTime();
        // Missing setUpEventCapture() → notifyFakeHandleAllEventsService is null → NPE!
    }
}
```

**Rationale:** `setUpEventCapture()` and `tearDownEventCapture()` are `protected` methods in BaseUseCaseTest with no `@BeforeEach`/`@AfterEach` annotations. Subclasses MUST manually call them. Forgetting causes `notifyFakeHandleAllEventsService` to be null, leading to NullPointerException during event verification. Use `public` visibility for compatibility with ezSpec `Feature.newScenario()` which uses `Class.getMethod()` (only finds public methods).

### Rule 3: @DirtiesContext AFTER_EACH_TEST_METHOD

```java
// ✅ CORRECT: Fresh context for each test
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {
}

// ❌ WRONG: AFTER_CLASS is not enough
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)  // Events accumulate!

// ❌ WRONG: Missing @DirtiesContext
@SpringBootTest
public class CreateProductServiceTest extends BaseUseCaseTest {  // Events leak between tests!
}
```

**Rationale:** EzesVolatileRelay is stateful; each test needs fresh Spring Context.

### Rule 4: Use @Autowired for Dependencies

```java
// ✅ CORRECT: Spring DI injection
@Autowired
private CreateProductUseCase createProductUseCase;

@Autowired
private Repository<Product, ProductId> productRepository;

// ❌ WRONG: Manual instantiation
private CreateProductService createProductService = new CreateProductService(
    new InMemoryRepository<>());  // FORBIDDEN!

// ❌ WRONG: TestContext pattern
TestContext.getInstance().getUseCase();  // FORBIDDEN!
```

### Rule 5: await() for Event Verification

```java
// ✅ CORRECT: Use await() with NotifyFakeHandleAllEventsService
import static org.awaitility.Awaitility.await;

.And("the ProductCreated event should be published", env -> {
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
        assertThat(notifyFakeHandleAllEventsService.handledEventTimes(
            ProductEvents.ProductCreated.class)).isEqualTo(1);
    });

    // Verify event content
    ProductEvents.ProductCreated event = (ProductEvents.ProductCreated)
        notifyFakeHandleAllEventsService.getLastHandledEvent();
    assertThat(event.productId().value()).isEqualTo(env.gets("productId"));
})

// ❌ WRONG: Direct assertion without await
.And("event published", env -> {
    // FAILS: Async events haven't arrived yet!
    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
})
```

**Rationale:** Events are published asynchronously via EzesVolatileRelay.

**Timeout:** 統一使用 **10 秒**。Outbox profile 的事件路徑（Aggregate → PG → CatchUpRelay → Producer → Broker → Consumer）比 InMemory 長，首次 context 初始化時更慢。5 秒以下會導致 Outbox profile 間歇性 `ConditionTimeoutException`。

**Return Type Warning:**
`getLastHandledEvent()` and `getHandledEvents()` return **`InternalDomainEvent`**, NOT `DomainEventData`.
The `NotifyFakeHandleAllEventsService` receives `DomainEventData` but immediately converts it via `DomainEventMapper.toDomain()` before storing. Cast directly to the concrete event record:

```java
// ✅ CORRECT: Cast to concrete domain event record
ProductEvents.ProductCreated event = (ProductEvents.ProductCreated)
    notifyFakeHandleAllEventsService.getLastHandledEvent();
event.productId();  // Access business fields directly

// ❌ WRONG: Assuming DomainEventData return type
DomainEventData data = notifyFakeHandleAllEventsService.getLastHandledEvent();  // Compile error!
```

### Rule 6: Command Tests MUST Verify Events

```java
// ✅ CORRECT: All command tests have event verification step
.Then("operation succeeds", env -> { /* ... */ })
.And("aggregate persisted", env -> { /* ... */ })
.And("event published", env -> {  // MANDATORY for commands!
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
    });
})
.Execute();

// ❌ WRONG: Missing event verification
.Then("operation succeeds", env -> { /* ... */ })
.And("aggregate persisted", env -> { /* ... */ })
.Execute();  // INCOMPLETE: No event verification!

// ✅ CORRECT: Error scenario MUST verify NO events leaked AND no entity persisted
.Then("the operation should fail", env -> {
    var output = env.get("output", CqrsOutput.class);
    assertThat(output.getExitCode()).isEqualTo(ExitCode.FAILURE);
})
.And("no aggregate should be persisted", env -> {  // MANDATORY for reject scenarios!
    var id = ${Aggregate}Id.valueOf(env.gets("${aggregateCamelCase}Id"));
    assertThat(${aggregateCamelCase}Repository.findById(id)).isEmpty();
})
.And("no domain events should be published", env -> {  // MANDATORY for error scenarios!
    long eventCountAfter = notifyFakeHandleAllEventsService.getHandledEventsSize();
    assertThat(eventCountAfter).isEqualTo(0);
})
.Execute();

// ❌ WRONG: Error scenario without negative repository assertion
.Then("the operation should fail", env -> { /* ... */ })
.And("no domain events should be published", env -> { /* ... */ })
.Execute();  // INCOMPLETE: Missing repository assertion — entity might be partially persisted!

// ❌ WRONG: Error scenario without negative event assertion
.Then("the operation should fail", env -> { /* ... */ })
.Execute();  // INCOMPLETE: Failed command might still leak events!
```

### Rule 7: ezSpec API Correct Usage

```java
// ✅ CORRECT: Use env.gets() for String
String productId = env.gets("productId");

// ✅ CORRECT: Use env.get(key, Type.class) for Objects
CqrsOutput output = env.get("output", CqrsOutput.class);
Product product = env.get("product", Product.class);

// ❌ WRONG: Casting from get()
String productId = (String) env.get("productId");  // Use gets() instead!
```

### Rule 8: CqrsOutput API Usage

```java
// ✅ CORRECT: Use getter methods
CqrsOutput output = env.get("output", CqrsOutput.class);
ExitCode code = output.getExitCode();
String id = output.getId();
String msg = output.getMessage();

// ❌ WRONG: Direct field access
output.exitCode  // Not a public field!
```

### Rule 9: Global TestSuite with @SelectPackages Pattern

> **全專案只有兩個 TestSuite**：`InMemoryTestSuite` + `OutboxTestSuite`。
> 不產生 per-use-case suite（如 ~~`InMemoryCreateProductTestSuite`~~）。
> 完整模板：`references/templates/test-suites.md`

```java
// ✅ CORRECT: Global TestSuite with @SelectPackages auto-discovery
@Suite
@SuiteDisplayName("Outbox Pattern Tests - PostgreSQL Database")
@SelectClasses({
    OutboxTestSuite.ProfileSetter.class   // ONLY ProfileSetter — no test classes!
})
@SelectPackages({
    "tw.teddysoft.aiscrum.product",       // Test classes auto-discovered per package
    "tw.teddysoft.aiscrum.sprint"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class OutboxTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-outbox");
            System.setProperty("spring.datasource.url", "jdbc:postgresql://localhost:${dbPort}/${dbName}?currentSchema=message_store");
            System.setProperty("spring.datasource.username", "postgres");
            System.setProperty("spring.datasource.password", "root");
            System.setProperty("spring.jpa.hibernate.ddl-auto", "update");
            System.setProperty("spring.jpa.properties.hibernate.default_schema", "message_store");
        }

        @Test
        void setProfile() {
        }
    }
}

// ❌ WRONG: Per-use-case TestSuite — creates unnecessary files
@Suite
@SelectClasses({
    InMemoryCreateProductTestSuite.ProfileSetter.class,
    CreateProductServiceTest.class,
})
public class InMemoryCreateProductTestSuite { ... }

// ❌ WRONG: @SelectClasses listing test classes — use @SelectPackages instead
@SelectClasses({
    OutboxTestSuite.ProfileSetter.class,
    CreateProductServiceTest.class,  // Wrong! Let @SelectPackages discover this
    DeleteProductServiceTest.class,
})

// ❌ WRONG: Static block in Suite class
@Suite
public class OutboxTestSuite {
    static {
        // This won't execute! JUnit Suite doesn't run static blocks
        System.setProperty("spring.profiles.active", "test-outbox");
    }
}
```

### Rule 10: AC Coverage 100% Required

```java
// ✅ CORRECT: Every AC has a test method
// AC1: Create product with valid data → should_create_product_successfully()
// AC2: Reject empty product name → should_reject_empty_product_name()
// AC3: Reject duplicate name → should_reject_duplicate_product_name()

// Verify coverage at end:
/*
 * AC Coverage Report:
 * - AC1: ✅ should_create_product_successfully (5/5 then conditions)
 * - AC2: ✅ should_reject_empty_product_name (2/2 then conditions)
 * - AC3: ✅ should_reject_duplicate_product_name (2/2 then conditions)
 * Total: 100% (3/3 ACs covered)
 */

// ❌ WRONG: Missing AC tests
// AC1: covered
// AC2: NOT COVERED  ← Incomplete!
// AC3: covered
```

### Rule 11: @EzScenario Methods MUST Be `public void` (No @Test Needed)

> **⚠️ CRITICAL**: `@EzScenario` is discovered by ezSpec's own test engine — **do NOT add `@Test`**.
> ezSpec uses `Class.getMethod()` (not `getDeclaredMethod()`) to discover
> `@EzScenario`-annotated methods. `getMethod()` can only find **public** methods.
> Missing the `public` modifier causes `NoSuchMethodException` **at runtime** (compiles fine!).

```java
// ✅ CORRECT: public modifier required
@EzScenario
public void should_create_product_successfully() {
    feature.newScenario()
        // ...
        .Execute();
}

// ❌ WRONG: package-private — compiles but throws NoSuchMethodException at runtime!
@EzScenario
void should_create_product_successfully() {
    feature.newScenario()
        // ...
        .Execute();
}
```

**Symptom**: Test compiles successfully but fails at runtime with:
```
java.lang.NoSuchMethodException: ...ServiceTest.should_create_product_successfully()
```

### Rule 12: Await-Then-Clear Pattern for Test Helpers with Async Events

> **⚠️ CRITICAL**: 當 Given 步驟需要呼叫前置 Use Case 來建立測試前置狀態時，
> `clearCapturedEvents()` 必須在 **確認前一個操作的事件已到達** 之後才能呼叫。
> 否則，前一個操作的事件可能在 clear 之後才抵達消費者，導致後續斷言計算到多餘的事件。

```java
// ✅ CORRECT: Await events THEN clear — ensures all prior events have arrived
private String createProductAndClearEvents(String name) {
    String productId = UUID.randomUUID().toString();
    var input = CreateProductUseCase.CreateProductInput.create();
    input.productId = productId;
    input.name = name;
    input.userId = "user-setup";
    createProductUseCase.execute(input);

    // MUST await before clearing — events are async via virtual thread
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
            assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                    .isGreaterThanOrEqualTo(1));
    clearCapturedEvents();

    return productId;
}

// ❌ WRONG: Clear immediately — race condition with async events!
private String createProductAndClearEvents(String name) {
    // ... execute use case ...
    createProductUseCase.execute(input);
    clearCapturedEvents();  // ProductCreated may arrive AFTER this clear!
    return productId;
}
```

**Symptom**: 後續操作的事件驗證 `assertThat(size).isEqualTo(1)` 失敗，實際得到 2
（前一個操作的事件 + 當前操作的事件）。

### Rule 12.1: Use isGreaterThanOrEqualTo(1) for CBF Event Count Assertions ⭐⭐

> **⚠️ CRITICAL**: CBF 測試中，狀態設置 helper（如 `createSprintInState()`）會先
> 執行前置 Command（如 CreateSprint → Start），再 await + clear。但由於 async relay
> 的 timing 不確定性，**前一操作的殘留事件可能在 clear 後才到達**。
>
> 因此，CBF 的 AC1 Then 步驟的事件計數斷言應使用 `isGreaterThanOrEqualTo(1)`
> 而非 `isEqualTo(1)`，以容忍跨操作的事件洩漏。

```java
// ✅ CORRECT: Tolerant assertion — accounts for async event leakage
.And("the SprintRenamed event should be published", env -> {
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                .isGreaterThanOrEqualTo(1);  // ← tolerant
        assertThat(notifyFakeHandleAllEventsService.getLastHandledEvent())
                .isInstanceOf(SprintEvents.SprintRenamed.class);
    });
})

// ❌ WRONG: Exact match — fails when prior events leak through
.And("event published", env -> {
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                .isEqualTo(1);  // ← brittle, fails with "Expected 1 but was 2"
    });
})
```

**何時用 `isEqualTo(1)` vs `isGreaterThanOrEqualTo(1)`**:

| 場景 | 建議 |
|------|------|
| SWF 測試（Given 無前置操作） | `isEqualTo(1)` — 無殘留事件風險 |
| CBF 測試（Given 有 createInState + clear） | `isGreaterThanOrEqualTo(1)` — 容忍洩漏 |
| Idempotent 場景（驗證無事件） | `isEqualTo(0)` — 必須精確 |

### Rule 13: (Removed)

> This rule about `@TestMethodOrder` has been removed. `@DirtiesContext(AFTER_EACH_TEST_METHOD)`
> ensures each test gets a fresh Spring Context, which is sufficient for test isolation.
> No `@TestMethodOrder` or `AC1_`/`AC2_` naming prefix is needed.

### Rule 14: Query Tests Must Clean Business Tables (Outbox Profile)

> **⚠️ CRITICAL**: `@DirtiesContext` 只重置 Spring Context（beans），**不會清理 PostgreSQL 資料**。
>
> **另外注意**：`tearDownEventCapture()` 在 `BaseUseCaseTest` 中也會清理 `message_store.messages` 表（Outbox profile）。
> 這是因為 CatchUpRelay 在 Spring Context 初始化時就啟動（`@Bean`），比 `@BeforeEach` 更早執行。
> 如果只在 `setUp()` 清理，新 relay 已經讀到舊資料了。詳見 `rules/testing-patterns.md` Error Pattern #7。
> InMemory Profile 的 `ConcurrentHashMap` 隨 Spring Context 重建而自動清空，但
> Outbox Profile 使用 PostgreSQL，資料在 Context 重建後仍然存在。
>
> Query 類測試（如 `return_empty_result_when_no_data_exists`）期望空表，
> 但會遇到其他測試的殘留資料。

```java
// ✅ CORRECT: Query test with Outbox profile cleanup
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class GetProductsServiceTest extends BaseUseCaseTest {

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @Autowired(required = false)
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();
        // Clean business table for Outbox profile — PostgreSQL data survives @DirtiesContext
        if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("DELETE FROM product");
            } catch (Exception e) {
                // Table may not exist in InMemory profile — ignore
            }
        }
        DateProvider.useSystemTime();
    }
}

// ❌ WRONG: No cleanup — residual data from other tests breaks assertions
@BeforeEach
public void setUp() {
    setUpEventCapture();
    DateProvider.useSystemTime();
    // Missing: Outbox profile has leftover data from previous tests!
}
```

**Symptom**: InMemory 測試全過，Outbox 測試在 "expect empty result" 場景失敗。

### Rule 14.5: List Query Tests Must Use Unique Filter Values ⭐⭐⭐ CRITICAL

> **⚠️ CRITICAL**: Rule 14 的 `DELETE FROM` 清理法只解決 "expect empty" 場景。
> 對於 **list query 斷言特定數量** 的場景（如 `hasSize(3)`），必須使用**隨機生成的 filter 值**。
>
> `@DirtiesContext` 只重建 Spring Context，**不清理 PostgreSQL 資料**。
> 即使用 `DELETE FROM`，也可能有 race condition 或其他測試平行寫入。
> 唯一可靠的隔離方式是讓每次測試的 filter 值都是唯一的。

```java
// ✅ CORRECT: 隨機 filter 值 — 每次測試唯一，不會撞舊資料
@EzScenario
void should_list_pbis_by_product() {
    feature.newScenario()
        .Given("2 PBIs exist for a specific product", env -> {
            String productId = "product-idf-" + UUID.randomUUID();  // ← 唯一！
            env.put("productId", productId);
            for (int i = 1; i <= 2; i++) {
                var input = CreatePbiUseCase.Input.create();
                input.productId = productId;
                input.name = "PBI " + i;
                createPbiUseCase.execute(input);
            }
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                            .isGreaterThanOrEqualTo(2));
            clearCapturedEvents();
        })
        .When("query PBIs by product", env -> {
            var input = GetPbisByProductUseCase.Input.create();
            input.productId = env.get("productId", String.class);
            output = getPbisByProductUseCase.execute(input);
        })
        .Then("2 PBIs are returned", env -> {
            assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
            assertThat(output.getPbis()).hasSize(2);  // ← 只有本次測試的 2 筆
        })
        .Execute();
}

// ❌ WRONG: hard-coded filter — Outbox profile 會撈到舊資料
String productId = "product-1";  // PG 裡可能有 66 筆舊 "product-1"！
// ... create 2 PBIs ...
assertThat(output.getPbis()).hasSize(2);  // 實際回傳 68！
```

**適用範圍**：所有回傳 list/collection 的查詢測試，filter 參數包括：
- `productId`、`sprintId`、`userId`、`boardId` 等所有 ID 類 filter
- 建議格式：`"{entity}-{usecase}-" + UUID.randomUUID()`

**與 Rule 14 的互補關係**：

| 場景 | Rule 14 (DELETE FROM) | Rule 14.5 (Unique Filter) |
|------|----------------------|--------------------------|
| Expect empty result | ✅ 必要 | 不需要 |
| Expect specific count | 不夠（race condition） | ✅ 必要 |
| 建議 | 兩個都用 | 兩個都用 |

### Rule 15: 禁止在 Lambda 中使用 Thread.sleep() ⭐⭐

> **⚠️ CRITICAL**: ezSpec 的 `env -> {}` lambda 不宣告 `throws`，因此
> `Thread.sleep()` 會導致 **unchecked `InterruptedException` 編譯錯誤**。
> 任何需要等待的場景，一律使用 Awaitility。

```java
// ✅ CORRECT: 使用 Awaitility 等待
import static org.awaitility.Awaitility.await;

.Given("setup with wait", env -> {
    // 等待一段時間
    await().during(500, TimeUnit.MILLISECONDS)
           .atMost(1, TimeUnit.SECONDS)
           .untilAsserted(() -> assertThat(true).isTrue());
})

// ✅ CORRECT: 等待事件到達
.And("event published", env -> {
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
    });
})

// ❌ WRONG: Thread.sleep() in lambda — 編譯錯誤！
.Given("setup with wait", env -> {
    Thread.sleep(500);  // ❌ Unhandled InterruptedException — lambda 不宣告 throws!
})

// ❌ WRONG: try-catch 包裝 — 多餘且不可靠
.Given("setup with wait", env -> {
    try {
        Thread.sleep(500);  // ❌ 不可靠的等待方式
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    }
})
```

**Symptom**: `Unhandled exception: java.lang.InterruptedException` 編譯錯誤，
出現在 ezSpec lambda 表達式中。

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Action |
|-------|--------|
| Read project-config.json | Check `dualProfileSupport` setting |
| Read test scenarios from spec | List all ACs and then conditions |
| Verify BaseUseCaseTest exists | If not, generate it first |

### Checkpoint 2: Post-Generation

```bash
# Compile check
cd ${projectRoot} && mvn test-compile -q -pl :${module} 2>&1 | head -20

# Verify no @ActiveProfiles
grep "@ActiveProfiles" ${testFile}
# Should return empty

# Run InMemory profile
SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest=${TestClass} -q

# Run Outbox profile (if dualProfileSupport=true)
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest=${TestClass} -q
```

### Checkpoint 3: Dual-Profile Test Verification Table

```
╔════════════════════════════════════════════════════════════════╗
║           DUAL-PROFILE TEST VERIFICATION TABLE                 ║
╠════════════════════════════════════════════════════════════════╣
║ Profile        │ Tests Run │ Passed │ Failed │ Status          ║
╠════════════════════════════════════════════════════════════════╣
║ test-inmemory  │     5     │   5    │   0    │ ✅ PASS         ║
║ test-outbox    │     5     │   5    │   0    │ ✅ PASS         ║
╠════════════════════════════════════════════════════════════════╣
║ OVERALL: ✅ BOTH PROFILES PASSED - Ready to proceed            ║
╚════════════════════════════════════════════════════════════════╝
```

### Checkpoint 4: AC Coverage Report

```
AC Coverage for CreateProduct:
╔═══════╦══════════════════════════════════╦════════════════╦════════════╗
║ AC ID ║ Description                      ║ Then Conditions║ Status     ║
╠═══════╬══════════════════════════════════╬════════════════╬════════════╣
║ AC1   ║ Create with valid data           ║ 5/5            ║ ✅ Covered ║
║ AC2   ║ Reject empty name                ║ 2/2            ║ ✅ Covered ║
║ AC3   ║ Reject duplicate name            ║ 2/2            ║ ✅ Covered ║
╚═══════╩══════════════════════════════════╩════════════════╩════════════╝
Total: 100% (3/3 ACs covered) ✅
```

---

<!-- @authority: command_input_type | source: patterns/usecase/command.md -->
<!-- @authority: test_input_construction | source: patterns/usecase/command.md -->

## GENERATION TEMPLATES

### Main Test Class

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import ${rootPackage}.${aggregateLowerCase}.entity.*;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.*;
import ${rootPackage}.common.entity.DateProvider;
import ${rootPackage}.test.base.BaseUseCaseTest;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;
import tw.teddysoft.ezspec.keyword.Feature;
import tw.teddysoft.ezspec.visitor.PlainTextReport;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * Use Case tests for ${UseCase}.
 * Tests verify Acceptance Criteria using ezSpec BDD.
 * Note: @DirtiesContext is inherited from BaseUseCaseTest — no need to redeclare.
 */
@SpringBootTest
// @DirtiesContext inherited from BaseUseCaseTest (AFTER_EACH_TEST_METHOD)
public class ${UseCase}ServiceTest extends BaseUseCaseTest {

    @Autowired
    private ${UseCase}UseCase ${useCaseCamelCase}UseCase;

    @Autowired
    private Repository<${Aggregate}, ${Aggregate}Id> ${aggregateCamelCase}Repository;

    private Feature feature;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();
        DateProvider.useSystemTime();
        feature = Feature.New("${UseCase}", "Verify ${UseCase} use case");
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture();
    }

    @AfterAll
    static void afterAll() {
        PlainTextReport report = new PlainTextReport();
        feature.accept(report);
        System.out.println(report.getOutput());
    }

    // ========== AC1: Success Scenario ==========

    // ⚠️ @EzScenario methods MUST be public void — Class.getMethod() only finds public (FC-11)
    @EzScenario
    public void should_${useCase}_successfully() {
        feature.newScenario()
            .Given("valid input data", env -> {
                // Prepare test data
                String ${aggregateCamelCase}Id = UUID.randomUUID().toString();
                env.put("${aggregateCamelCase}Id", ${aggregateCamelCase}Id);
                var input = ${UseCase}UseCase.${UseCase}Input.create();
                input.${aggregateCamelCase}Id = ${aggregateCamelCase}Id;
                // ... other field assignments
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the use case is executed", env -> {
                var input = env.get("input", ${UseCase}UseCase.${UseCase}Input.class);
                var output = ${useCaseCamelCase}UseCase.execute(input);
                env.put("output", output);
            })
            .Then("the operation should succeed", env -> {
                var output = env.get("output", CqrsOutput.class);
                assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
                assertThat(output.getId()).isEqualTo(env.gets("${aggregateCamelCase}Id"));
            })
            .And("the aggregate should be persisted", env -> {
                var id = ${Aggregate}Id.valueOf(env.gets("${aggregateCamelCase}Id"));
                var aggregate = ${aggregateCamelCase}Repository.findById(id).orElse(null);
                assertThat(aggregate).isNotNull();
                // Verify aggregate state...
            })
            .And("the ${EventName} event should be published", env -> {
                await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
                    assertThat(notifyFakeHandleAllEventsService.handledEventTimes(
                        ${Aggregate}Events.${EventName}.class)).isEqualTo(1);
                });

                ${Aggregate}Events.${EventName} event = (${Aggregate}Events.${EventName})
                    notifyFakeHandleAllEventsService.getLastHandledEvent();
                assertThat(event.${aggregateCamelCase}Id().value())
                    .isEqualTo(env.gets("${aggregateCamelCase}Id"));
            })
            .Execute();
    }

    // ========== AC2: Error Scenario (Business Rule Rejection) ==========

    // ⚠️ @EzScenario methods MUST be public void — Class.getMethod() only finds public (FC-11)
    @EzScenario
    public void should_reject_invalid_input() {
        feature.newScenario()
            .Given("invalid input data", env -> {
                var ${aggregateCamelCase}Id = UUID.randomUUID().toString();
                env.put("${aggregateCamelCase}Id", ${aggregateCamelCase}Id);
                var input = ${UseCase}UseCase.${UseCase}Input.create();
                input.${aggregateCamelCase}Id = ${aggregateCamelCase}Id;
                input.name = "";  // Invalid: empty required field
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the use case is executed", env -> {
                var input = env.get("input", ${UseCase}UseCase.${UseCase}Input.class);
                try {
                    var output = ${useCaseCamelCase}UseCase.execute(input);
                    env.put("output", output);
                    env.put("exceptionThrown", false);
                } catch (Exception e) {
                    env.put("exception", e);
                    env.put("exceptionThrown", true);
                }
            })
            .Then("the operation should fail", env -> {
                if (env.get("exceptionThrown", Boolean.class)) {
                    var exception = env.get("exception", Exception.class);
                    assertThat(exception).isNotNull();
                } else {
                    var output = env.get("output", CqrsOutput.class);
                    assertThat(output.getExitCode()).isEqualTo(ExitCode.FAILURE);
                }
            })
            .And("no ${aggregateCamelCase} should be persisted", env -> {  // MANDATORY for reject scenarios!
                var id = ${Aggregate}Id.valueOf(env.gets("${aggregateCamelCase}Id"));
                assertThat(${aggregateCamelCase}Repository.findById(id)).isEmpty();
            })
            .And("no domain events should be published", env -> {
                long eventCountAfter = notifyFakeHandleAllEventsService.getHandledEventsSize();
                assertThat(eventCountAfter).isEqualTo(0);
            })
            .Execute();
    }
}
```

### Global TestSuite（不需每次產生）

> **全專案只有兩個 TestSuite**：`InMemoryTestSuite` + `OutboxTestSuite`。
> 第一次 PF 執行時建立，後續只需確認 `@SelectPackages` 包含新 aggregate 的 package。
> 完整模板：`references/templates/test-suites.md`
>
> **PF 執行時的 TestSuite 檢查邏輯**：
> 1. 檢查 `InMemoryTestSuite.java` 是否存在 → 不存在則建立
> 2. 檢查 `OutboxTestSuite.java` 是否存在 → 不存在則建立
> 3. 檢查 `@SelectPackages` 是否包含當前 aggregate 的 package → 不包含則加入

---

## EXAMPLE OUTPUT

### CreateProductServiceTest.java

```java
package tw.teddysoft.aiscrum.product.usecase.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import tw.teddysoft.aiscrum.product.entity.*;
import tw.teddysoft.aiscrum.product.usecase.port.in.*;
import tw.teddysoft.aiscrum.common.entity.DateProvider;
import tw.teddysoft.aiscrum.test.base.BaseUseCaseTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;
import tw.teddysoft.ezspec.keyword.Feature;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

@SpringBootTest
// @DirtiesContext inherited from BaseUseCaseTest; @TestMethodOrder removed (Rule 13)
public class CreateProductServiceTest extends BaseUseCaseTest {

    @Autowired
    private CreateProductUseCase createProductUseCase;

    @Autowired
    private Repository<Product, ProductId> productRepository;

    private Feature feature;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();
        DateProvider.useSystemTime();
        feature = Feature.New("CreateProduct", "Create a new product");
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture();
    }

    @EzScenario
    public void should_create_product_successfully() {
        feature.newScenario()
            .Given("a valid product creation request", env -> {
                String productId = UUID.randomUUID().toString();
                env.put("productId", productId);
                env.put("productName", "Test Product");
                var input = CreateProductUseCase.CreateProductInput.create();
                input.productId = productId;
                input.name = "Test Product";
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the create product use case is executed", env -> {
                var input = env.get("input", CreateProductUseCase.CreateProductInput.class);
                var output = createProductUseCase.execute(input);
                env.put("output", output);
            })
            .Then("the operation should succeed", env -> {
                var output = env.get("output", CqrsOutput.class);
                assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
                assertThat(output.getId()).isEqualTo(env.gets("productId"));
            })
            .And("the product should be persisted", env -> {
                var productId = ProductId.valueOf(env.gets("productId"));
                var product = productRepository.findById(productId).orElse(null);
                assertThat(product).isNotNull();
                assertThat(product.getName().value()).isEqualTo(env.gets("productName"));
            })
            .And("the ProductCreated event should be published", env -> {
                await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
                    assertThat(notifyFakeHandleAllEventsService.handledEventTimes(
                        ProductEvents.ProductCreated.class)).isEqualTo(1);
                });

                ProductEvents.ProductCreated event = (ProductEvents.ProductCreated)
                    notifyFakeHandleAllEventsService.getLastHandledEvent();
                assertThat(event.productId().value()).isEqualTo(env.gets("productId"));
            })
            .Execute();
    }

    @EzScenario
    public void should_reject_empty_product_name() {
        feature.newScenario()
            .Given("a product creation request with empty name", env -> {
                var input = CreateProductUseCase.CreateProductInput.create();
                input.productId = UUID.randomUUID().toString();
                input.name = "";
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the create product use case is executed", env -> {
                var input = env.get("input", CreateProductUseCase.CreateProductInput.class);
                try {
                    var output = createProductUseCase.execute(input);
                    env.put("output", output);
                    env.put("exceptionThrown", false);
                } catch (Exception e) {
                    env.put("exception", e);
                    env.put("exceptionThrown", true);
                }
            })
            .Then("the operation should fail", env -> {
                if (env.get("exceptionThrown", Boolean.class)) {
                    assertThat(env.get("exception", Exception.class)).isNotNull();
                } else {
                    var output = env.get("output", CqrsOutput.class);
                    assertThat(output.getExitCode()).isEqualTo(ExitCode.FAILURE);
                }
            })
            .And("no product should be persisted", env -> {
                var input = env.get("input", CreateProductUseCase.CreateProductInput.class);
                assertThat(productRepository.findById(ProductId.valueOf(input.productId))).isEmpty();
            })
            .And("no domain events should be published", env -> {
                long eventCountAfter = notifyFakeHandleAllEventsService.getHandledEventsSize();
                assertThat(eventCountAfter).isEqualTo(0);
            })
            .Execute();
    }
}
```

---

## SPECIAL CASES

### Query Test Class setUp — Outbox Profile DB Cleanup (Rule 14)

> **⚠️ CRITICAL**: Query 測試必須在 setUp() 中清理業務資料表（Outbox profile only）。
> 見 Rule 14 完整說明。

```java
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class ${QueryUseCase}ServiceTest extends BaseUseCaseTest {

    @Autowired
    private ${QueryUseCase}UseCase ${queryUseCaseCamelCase}UseCase;

    @Autowired
    private CreateProductUseCase createProductUseCase;  // For Given step data setup

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @Autowired(required = false)
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();
        // Query tests: clean business table for Outbox profile (Rule 13)
        if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("DELETE FROM ${tableName}");
            } catch (Exception e) {
                // Table may not exist in InMemory profile — ignore
            }
        }
        DateProvider.useSystemTime();
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture();
    }
}
```

### Query Use Case with Data Setup (Rule 14.5: Unique Filter Values)

```java
@EzScenario
public void should_get_products_list() {
    feature.newScenario()
        .Given("multiple products exist", env -> {
            // ⚠️ Rule 14.5: 使用唯一 filter 值，避免 Outbox PG 舊資料汙染
            String userId = "user-list-" + UUID.randomUUID();
            env.put("userId", userId);
            // Create products through use cases
            for (int i = 1; i <= 3; i++) {
                var input = CreateProductUseCase.CreateProductInput.create();
                input.productId = UUID.randomUUID().toString();
                input.name = "Product " + i;
                input.userId = userId;  // ← 唯一 filter 值
                createProductUseCase.execute(input);
            }
            // Await-then-clear: wait for all 3 async events to arrive before clearing
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                            .isGreaterThanOrEqualTo(3));
            clearCapturedEvents();
        })
        .When("the get products use case is executed", env -> {
            var input = GetProductsUseCase.GetProductsInput.create();
            input.userId = env.get("userId", String.class);
            var output = getProductsUseCase.execute(input);
            env.put("output", output);
        })
        .Then("three products should be returned", env -> {
            var output = env.get("output", GetProductsUseCase.Output.class);
            assertThat(output.exitCode()).isEqualTo(ExitCode.SUCCESS);
            assertThat(output.products()).hasSize(3);  // ← 只有本次測試的 3 筆
        })
        .Execute();
}
```

### Test with Pre-existing Aggregate State

```java
@EzScenario
public void should_start_sprint_from_planned_state() {
    feature.newScenario()
        .Given("a sprint in PLANNED state", env -> {
            // Create sprint
            String sprintId = UUID.randomUUID().toString();
            var createInput = CreateSprintUseCase.CreateSprintInput.create();
            createInput.productId = productId;
            createInput.sprintId = sprintId;
            createInput.name = "Sprint 1";
            createInput.startDate = start;
            createInput.endDate = end;
            createInput.userId = "user-1";
            createSprintUseCase.execute(createInput);
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() ->
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                            .isGreaterThanOrEqualTo(1));
            clearCapturedEvents();
            env.put("sprintId", sprintId);
        })
        .When("the start sprint use case is executed", env -> {
            var input = StartSprintUseCase.StartSprintInput.create();
            input.sprintId = env.gets("sprintId");
            input.userId = "user-1";
            var output = startSprintUseCase.execute(input);
            env.put("output", output);
        })
        .Then("the sprint should be started", env -> {
            var output = env.get("output", CqrsOutput.class);
            assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);

            var sprint = sprintRepository.findById(SprintId.valueOf(env.gets("sprintId"))).orElse(null);
            assertThat(sprint.getState()).isEqualTo(SprintState.STARTED);
        })
        .And("SprintStarted event should be published", env -> {
            await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                assertThat(notifyFakeHandleAllEventsService.handledEventTimes(
                    SprintEvents.SprintStarted.class)).isEqualTo(1);
            });
        })
        .Execute();
}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.3: Invoke usecase-test-skill
    ├─ Input: UseCase.java, JSON spec testScenarios[]
    ├─ Output: {UseCase}ServiceTest.java
    ├─ TestSuite: Check global InMemoryTestSuite/OutboxTestSuite exist,
    │            add aggregate package to @SelectPackages if needed
    └─ Next: Dual-profile verification
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| @ActiveProfiles found | Remove immediately - breaks dual-profile |
| Event verification timeout (all tests) | Check BaseUseCaseTest.setUpEventCapture() is called |
| Event verification timeout (Outbox only, intermittent) | Check `setUpEventCapture()` includes stale-event cleanup for outbox profile; verify `clearCapturedEvents()` in Given steps. @TestMethodOrder is NOT needed (Rule 13 removed) — `@DirtiesContext(AFTER_EACH_TEST_METHOD)` ensures test isolation. |
| Events accumulate between tests | Add @DirtiesContext(AFTER_EACH_TEST_METHOD) |
| Missing BaseUseCaseTest | Generate it first using base-test-skill |
| TestSuite profile not switching | Ensure ProfileSetter is in @SelectClasses; check @SelectPackages includes aggregate package |
| AC coverage < 100% | Add missing test methods for each AC |
| Test passes InMemory, fails Outbox | Check PostgreSQL connection and ddl-auto setting |

---
