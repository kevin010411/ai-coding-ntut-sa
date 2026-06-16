# Testing Patterns (ezddd-java)

## ⚠️ WHAT WILL GO WRONG (必讀!) ⭐⭐⭐

### 錯誤 1: 缺少 @DirtiesContext ← 最常見！

```java
// ❌ 錯誤
@SpringBootTest
public class CreateProductServiceTest extends BaseUseCaseTest {
    // 沒有 @DirtiesContext
}
```

**症狀**:
- 第一個測試通過，後續測試失敗
- 事件驗證超時
- `EzesVolatileRelay` 無法重啟

**根本原因**: `EzesVolatileRelay` 是有狀態的 `Runnable`，`shutdownNow()` 後無法重啟

**修復**:
```java
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest { }
```

### 錯誤 2: 使用 @ActiveProfiles

```java
// ❌ 錯誤
@ActiveProfiles("test-inmemory")
public class CreateProductServiceTest { }
```

**症狀**:
- TestSuite 無法切換 Profile
- InMemory 和 Outbox 無法用同一測試類別

**修復**: 移除 @ActiveProfiles，使用環境變數或 ProfileSetter

### 錯誤 3: 缺少 application-test-inmemory.properties

**症狀**:
```
Failed to determine a suitable driver class
Error creating bean with name 'flyway'
Error creating bean with name 'entityManagerFactory'
```

**修復**: 建立 `src/test/resources/application-test-inmemory.properties`（見下方配置）

### 錯誤 4: 未手動呼叫 setUpEventCapture()

```java
// ❌ 錯誤：沒有呼叫 setUpEventCapture()
@BeforeEach
void setUp() {
    DateProvider.useSystemTime();
    // 缺少 setUpEventCapture()！事件捕獲不會初始化
}
```

**症狀**:
- 事件捕獲未初始化
- notifyFakeHandleAllEventsService 為 null

**修復**: 子類別 @BeforeEach 必須呼叫 `setUpEventCapture()`，
@AfterEach 必須呼叫 `tearDownEventCapture()`

```java
// ✅ 正確
@BeforeEach
void setUp() {
    setUpEventCapture();  // protected 方法，子類別必須手動呼叫
    DateProvider.useSystemTime();
}

@AfterEach
void tearDown() {
    tearDownEventCapture();  // protected 方法，子類別必須手動呼叫
}
```

### 錯誤 5: getCapturedEvents() 不使用 lastPolledIndex

```java
// ❌ 錯誤
protected List<DomainEvent> getCapturedEvents() {
    return consumer.poll(0, 1000);  // 總是從頭讀取！
}
```

**症狀**:
- `clearCapturedEvents()` 無效
- 讀取到舊事件

**修復**: 使用 `poll(lastPolledIndex, 1000)` 並追蹤索引

### 錯誤 6: Outbox 測試中使用 Thread.sleep() 等待後驗證事件數量 ← 競態條件！

```java
// ❌ 錯誤：等待期間 CatchUpRelay 可能重複處理事件
.And("No additional events published", env -> {
    Thread.sleep(500);  // 危險！
    long eventCount = notifyFakeService.handledEventTimes(SomeEvent.class);
    assertThat(eventCount).isEqualTo(0);  // 可能因 relay 重複處理而失敗
})
```

**症狀**:
- InMemory profile 測試通過，Outbox profile 測試失敗
- 事件數量比預期多（如 expected=1, actual=2）
- 業務邏輯正確但事件驗證失敗

**根本原因**:
- `EzesCatchUpRelay` 會定期從資料庫輪詢 messages 表
- 在 `Thread.sleep()` 期間，relay 可能重複讀取並處理同一個事件
- 這不是 Service 的問題，是測試的競態條件

**修復方案**:

```java
// ✅ 正確：使用 Feature.New() API，在 When 步驟開始時記錄，Then 步驟立即驗證（不等待）
Feature.New("My Feature")
    .newScenario()
    .Given("An entity already exists", env -> {
        // ... 建立第一個實體 ...
        await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
            assertTrue(notifyFakeService.handledEventTimes(SomeCreated.class) >= 1);
        });
        // 不在這裡記錄 eventCountBefore！CatchUpRelay 可能還在處理
    })
    .When("Duplicate create is attempted", env -> {
        // ✅ 在 When 開始時記錄（最準確的時間點）
        long eventCountBefore = notifyFakeService.handledEventTimes(SomeCreated.class);
        env.put("eventCountBefore", eventCountBefore);

        // 執行操作
        CqrsOutput<?> output = useCase.execute(duplicateInput);
        env.put("output", output);
    })
    .Then("Request fails", env -> {
        CqrsOutput<?> output = env.get("output", CqrsOutput.class);
        assertEquals(ExitCode.FAILURE, output.getExitCode());
    })
    .And("No additional events published", env -> {
        // ✅ 立即驗證，不要 sleep！
        long eventCountBefore = env.get("eventCountBefore", Long.class);
        long eventCountAfter = notifyFakeService.handledEventTimes(SomeCreated.class);
        assertEquals(eventCountBefore, eventCountAfter);
    })
    .Execute();
```

**關鍵原則**:
1. **在 When 步驟開始時記錄 eventCountBefore**（不是 Given 結束時）
2. **Then 步驟立即驗證**（不使用 Thread.sleep）
3. **驗證「數量不變」而非「數量為 0」**

### 錯誤 7: Outbox tearDown 缺少 message 清理 ← CatchUpRelay 競態條件！

```java
// ❌ 錯誤：tearDown 沒有清理 message_store.messages
protected void tearDownEventCapture() {
    if (executorService != null) {
        executorService.shutdownNow();
    }
    // 沒有清理 messages table！
}
```

**症狀**:
- 單獨跑一個測試通過，連續跑多個測試時 `ConditionTimeoutException`
- AC1 事件斷言超過 5 秒後超時
- 只在 Outbox profile 出現，InMemory profile 正常

**根本原因**:
- `@DirtiesContext(AFTER_EACH_TEST_METHOD)` 在每個測試後銷毀 Spring Context
- 下一個測試的新 Context 建立新的 `CatchUpRelay`（從 position 0 開始）
- 新 relay 會讀取 `message_store.messages` 中**前一個測試留下的舊訊息**
- `setUpEventCapture()` 的清理（`DELETE FROM messages` + `clearHandledEvents()`）在 `@BeforeEach` 中執行
- 但 CatchUpRelay 在 Spring Context 初始化時（`CatchupRelayConfig.@Bean`）就啟動了，**早於** `@BeforeEach`
- 因此 setUp 清理已經太晚，relay 已經轉發了舊訊息

**時序圖**:
```
Test N 結束 → @DirtiesContext 銷毀 Context
           → Test N+1 新 Context 建立
           → CatchupRelayConfig.@Bean → CatchUpRelay 啟動 (position 0)
           → CatchUpRelay 讀取前一個測試的舊 messages ← 問題！
           → @BeforeEach → setUpEventCapture() 清理 ← 太晚！
```

**修復**:
```java
// ✅ 正確：在 tearDown 中清理 messages（在 Context 銷毀前）
protected void tearDownEventCapture() {
    if (executorService != null) {
        executorService.shutdownNow();
        try {
            if (!executorService.awaitTermination(1, TimeUnit.SECONDS)) {
                System.out.println("ExecutorService did not terminate in time");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    // ⭐ CRITICAL: 必須在 tearDown 清理，不能只在 setUp 清理
    // 原因：CatchUpRelay 在 Spring Context 初始化時啟動（早於 @BeforeEach）
    if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
        try {
            jdbcTemplate.execute("DELETE FROM message_store.messages");
            jdbcTemplate.execute("ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1");
        } catch (Exception e) {
            System.err.println("tearDown: Could not clean messages table: " + e.getMessage());
        }
    }
}
```

**關鍵原則**:
1. **tearDown 清理是主要防線**：確保 Context 銷毀前 messages 已清空
2. **setUp 清理是防禦縱深**：保留作為二次保障（加上 sleep + clearHandledEvents）
3. **兩者缺一不可**：tearDown 處理正常流程，setUp 處理異常情況（如前一個測試 crash）
4. **List query 測試**：必須使用 UUID-based 唯一 filter 值（如 `"product-" + UUID.randomUUID()`），
   因為 `DELETE FROM` 無法可靠隔離平行測試或跨 suite 的殘留資料。
   詳見 `usecase-test.md` Rule 14.5。

### 錯誤 7.1: Batch-Mode Relay 汙染（VolatileRelay 跨測試類別殘留）

**症狀**:
- 單獨跑測試通過，全套 `mvn test` 隨機 1 個測試失敗
- 排除該測試後，另一個測試接替失敗（失敗位置不固定）
- 錯誤訊息：`EntityManagerFactory is closed` 或 `ConditionTimeoutException`

**診斷**: 這不是程式碼 bug。EzesVolatileRelay 的背景 VirtualThread
在 @DirtiesContext 銷毀 Context 後仍短暫存活，干擾下一個 Context 的 relay。

**處理**: 記錄為 known flaky，無需修改測試。單獨執行驗證功能正確性。

### 錯誤 8: IDF List Query 返回 Stale Data ← Outbox Profile 限定！

```java
// ❌ 錯誤：IDF list query test 沒有清理 entity table
@BeforeEach
void setUp() {
    setUpEventCapture();
    // 沒有清理 product table！Outbox profile 會讀到之前測試的殘留資料
}
```

**症狀**:
- InMemory profile 測試通過（每次 ConcurrentHashMap 都是空的）
- Outbox profile 測試失敗：`Expected size: 2 but was: 22`
- `queryAll()` 返回之前所有測試留下的資料

**根本原因**:
- `@DirtiesContext(AFTER_EACH_TEST_METHOD)` 只重建 Spring Context
- **不會清理** PostgreSQL 資料表
- InMemory profile 每次 Context 都建新的 `ConcurrentHashMap`，所以沒問題
- Outbox profile 的 `OrmClient.findAll()` 讀的是 **持久化資料庫**，殘留資料會累積

**修復**:
```java
// ✅ 正確：IDF list query 測試必須在 Outbox profile 清理 entity table
@BeforeEach
void setUp() {
    setUpEventCapture();
    if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
        try {
            jdbcTemplate.execute("DELETE FROM product");  // 清理 entity table
        } catch (Exception e) {
            System.err.println("Could not clean product table: " + e.getMessage());
        }
    }
}
```

**關鍵原則**:
1. **只有 IDF list query 測試需要此清理**：Command 測試不受影響（它們測試個別操作）
2. **只有 `queryAll()` / `findAll()` 受影響**：`findById()` 用確定的 ID 查詢不會被干擾
3. **InMemory profile 不需要此清理**：每次 Context 都是全新的 ConcurrentHashMap
4. **Entity table 名稱對應 `@Table(name = "xxx")`**：檢查 PersistentObject 的 `@Table` 註解

### 錯誤 9: Outbox 首次測試執行失敗 — Pre-flight Cleanup 缺失 ← Schema 變更後必現！

> **ROOT CAUSE (Workflow CBF Failures F2 + F5)**: 首次執行 Outbox profile 測試時，
> 或在 aggregate schema 新增欄位後，可能遇到兩種互相關聯的問題。

**問題 A — CatchupRelay Checkpoint Race Condition (F2)**:

```
CatchupRelay 啟動 → 讀取舊 messages → 推進 checkpoint
→ setUpEventCapture() 清理 messages 並重設 sequence
→ 新 events 從 position 1 開始寫入
→ Relay checkpoint 已超過 position 1 → 永遠看不到新 events
→ Test await() 超時 → ConditionTimeoutException
```

**問題 B — NOT NULL Column on Existing Rows (F5)**:

```
aggregate.yaml 新增欄位（如 display_order）
→ Hibernate ddl-auto=update 試圖 ALTER TABLE ADD COLUMN ... NOT NULL
→ 表中有前一次測試的舊資料（沒有該欄位值）
→ PostgreSQL 拒絕：ERROR: column contains null values
```

**修復 — Outbox Test Pre-flight Cleanup SQL**:

```sql
-- 在首次執行 Outbox tests 或 schema 變更後，先手動執行：
DELETE FROM message_store.messages;
ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1;
DROP TABLE IF EXISTS message_store.<aggregate_table> CASCADE;
-- Hibernate ddl-auto=update 會自動重建 table
```

**PF Executor 整合**:
- Step 6 (Outbox testing) 執行前，如果是該 aggregate 的首次 Outbox 測試或偵測到 schema 變更，
  應自動執行 pre-flight cleanup SQL
- `BaseUseCaseTest.setUpEventCapture()` 處理後續測試間的清理，但無法處理首次啟動的殘留問題

**關鍵原則**:
1. **首次 Outbox 測試前必須清理** messages table 和 aggregate table
2. **Schema 變更後必須 DROP aggregate table**（`ddl-auto=update` 無法在有資料的表上加 NOT NULL 欄位）
3. **`setUpEventCapture()` 只能處理同 session 內的清理**，不能處理跨 session 殘留

---

## Event Verification API Reference

`NotifyFakeHandleAllEventsService` is a **separate class** in `${rootPackage}.common` (under src/test/java).
It implements `Reactor<DomainEventData>` and stores events as **`InternalDomainEvent`** (converted via `DomainEventMapper.toDomain()`).
Uses `ArrayList` (not `CopyOnWriteArrayList`) since event processing is sequential.

| Method | Return Type | Purpose |
|--------|-------------|---------|
| `getHandledEvents()` | `List<InternalDomainEvent>` | All captured events |
| `getLastHandledEvent()` | `InternalDomainEvent` | Most recent event |
| `handledEventTimes(Class<?>)` | `long` | Count of specific event type |
| `getHandledEventsSize()` | `int` | Total captured event count |
| `clearHandledEvents()` | `void` | Reset captured events |

**Event Assertion API 使用指引**：

| 場景 | 推薦 API | 原因 |
|------|---------|------|
| SWF 成功（無前置事件） | `handledEventTimes(XxxCreated.class)` + `isEqualTo(1)` | 精確驗證特定事件類型 |
| CBF 成功（有前置事件） | `handledEventTimes(XxxEvent.class)` + `isGreaterThanOrEqualTo(1)` | 容忍前置事件殘留 |
| Error/Idempotent（CBF） | `handledEventTimes(Class)` before/after 比較 | 確保無新增特定事件 |
| Error/Idempotent（SWF） | `getHandledEventsSize()` + `isEqualTo(0)` | 無前置事件，可用總數 |

> **原則**：優先使用 `handledEventTimes(Class)` 驗證特定事件類型。
> `getHandledEventsSize()` 僅在確定無前置事件的 SWF error 場景中使用。

```java
// ✅ Cast to concrete domain event record
ProductEvents.ProductCreated event = (ProductEvents.ProductCreated)
    notifyFakeHandleAllEventsService.getLastHandledEvent();
event.productId();  // Access business fields directly

// ❌ WRONG: Return type is NOT DomainEventData
DomainEventData data = notifyFakeHandleAllEventsService.getLastHandledEvent();  // Compile error!
```

---

## Dual Profile Testing

When `dualProfileSupport = true` in project-config.json, generate **3 test files**:

1. **{UseCase}ServiceTest.java** - Main test (ezSpec BDD)

> **TestSuite 是全域的**（`InMemoryTestSuite` + `OutboxTestSuite`），不是 per-use-case 產生。
> 完整模板：`references/templates/test-suites.md`

### Package Location Rules (CRITICAL)

| File Type | Package | Example |
|-----------|---------|---------|
| `{UseCase}ServiceTest.java` | `{aggregate}.usecase.service` | `product/usecase/service/CreateProductServiceTest.java` |
| `InMemoryTestSuite.java` | `test.suite` | `test/suite/InMemoryTestSuite.java` (全專案一個) |
| `OutboxTestSuite.java` | `test.suite` | `test/suite/OutboxTestSuite.java` (全專案一個) |
## ProfileSetter Pattern — Inner Class (Canonical)

> **完整參考**: `references/examples/dual-profile-test-infrastructure.md` Section 9

**CRITICAL DISCOVERY**: JUnit Platform Suite's static blocks DON'T execute!
- Static blocks in @Suite classes are NEVER executed
- Static blocks in @SelectClasses[0] ARE executed

**Canonical Pattern**: 全專案只有兩個 Global TestSuite，ProfileSetter 是 inner class，
`@SelectPackages` 自動掃描測試類別。

### Global TestSuite with @SelectPackages

```java
@Suite
@SuiteDisplayName("In-Memory Tests - Fast Execution")
@SelectClasses({
    InMemoryTestSuite.ProfileSetter.class    // ONLY ProfileSetter — test classes auto-discovered
})
@SelectPackages({
    "tw.teddysoft.aiscrum.product",          // aggregate packages
    "tw.teddysoft.aiscrum.sprint"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class InMemoryTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-inmemory");
            System.setProperty("spring.autoconfigure.exclude",
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                            "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration");
        }

        @Test
        void setProfile() {
        }
    }
}
```

## BaseUseCaseTest Rules (CRITICAL)

```java
// ✅ CORRECT: Subclass MUST manually call setUpEventCapture/tearDownEventCapture
//            setUp/tearDown 建議用 public（確保子類別可見性一致，且部分 test framework 需要 public lifecycle methods）
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {

    @BeforeEach
    public void setUp() {
        setUpEventCapture();    // MUST call — protected, not auto-invoked
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture(); // MUST call — protected, not auto-invoked
    }
}

// ❌ WRONG: Forgetting to call setUpEventCapture
public class WrongTest extends BaseUseCaseTest {

    @BeforeEach
    void setUp() {
        DateProvider.useSystemTime();
        // Missing setUpEventCapture() → events not captured!
    }
}
```

### Why @DirtiesContext?

- `EzesVolatileRelay` is stateful Runnable, cannot restart after `shutdownNow()`
- `AFTER_EACH_TEST_METHOD` ensures each test has clean Spring Context
- Prevents test interference and random failures

## ezSpec BDD Pattern ⭐⭐⭐ CRITICAL — API 已驗證 (2026-01-30)

> **來源**: ezspec-core 2.0.4 JAR 反編譯驗證
> **核心類別**: `tw.teddysoft.ezspec.keyword.Feature`, `tw.teddysoft.ezspec.keyword.ScenarioEnvironment`

### 正確用法

```java
import tw.teddysoft.ezspec.keyword.Feature;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;

@EzScenario
public void create_a_valid_product_with_required_fields_only() {  // ⚠️ 必須 public！
    Feature.New("Create Product")
            .newScenario()
            .Given("A user user-123 is authorized to create products", env -> {
                // setup — env 是 ScenarioEnvironment，可用 env.put(key, value) 存資料
            })
            .When("The user creates a product with name My Product", env -> {
                CqrsOutput<?> output = createProductUseCase.execute(input);
                assertEquals(ExitCode.SUCCESS, output.getExitCode());
                env.put("output", output);
            })
            .Then("A ProductCreated domain event is published", env -> {
                await().untilAsserted(() -> {
                    assertTrue(notifyFakeHandleAllEventsService.getHandledEventsSize() >= 1);
                });
            })
            .Execute();
}
```

### ⚠️ CRITICAL RULES

| 規則 | 正確 | 錯誤 |
|------|------|------|
| **Feature 建立** | `Feature.New("name")` | `feature("name")`, `EzScenario.feature("name")` |
| **Scenario 建立** | `.newScenario()` (無參數) | `.newScenario("name")` (有參數版本會查找 pre-registered Rule), `.scenario("name")` |
| **步驟方法名** | `.Given()`, `.When()`, `.Then()` (大寫) | `.given()`, `.when()`, `.then()` (小寫) |
| **執行** | `.Execute()` | `.perform()`, `.run()` |
| **Lambda 型別** | `Consumer<ScenarioEnvironment>` (`env -> {}`) | `Runnable` (`() -> {}`) |
| **方法可見性** | `public void` | `void` (package-private) |
| **方法標注** | `@EzScenario` only（不加 `@Test`） | `@EzScenario` + `@Test`（多餘，可能重複執行） |
| **EzScenario** | 是 JUnit5 `@Annotation`，由 ezSpec test engine 驅動 | 不是有靜態方法的類別 |

### 為什麼方法必須是 public？

`Feature.newScenario()` 內部使用 `Class.getMethod()` 取得呼叫方法名稱來決定 Rule。
`getMethod()` 只能找到 **public** 方法。如果測試方法是 package-private，會拋出：
```
RuntimeException: tw.teddysoft.aiscrum.xxx.XxxServiceTest.test_method_name()
Caused by: NoSuchMethodException
```

### ScenarioEnvironment 跨步驟傳遞資料

```java
// Given 步驟存資料
.Given("...", env -> {
    env.put("productId", UUID.randomUUID().toString());
})
// When 步驟取用
.When("...", env -> {
    String productId = env.gets("productId");  // gets() 取 String
    // 或使用泛型：env.get("key", Long.class), env.geti("key") for int
})
```

### 錯誤的 API 用法（常見陷阱）

```java
// ✅ 唯一正確的 @EzScenario import:
import tw.teddysoft.ezspec.extension.junit5.EzScenario;

// ❌ 全部錯誤！
import tw.teddysoft.ezspec.EzScenario;                            // ❌ 不存在的路徑
import tw.teddysoft.ezspec.testannotation.EzScenario;             // ❌ 不存在的路徑
EzScenario.feature("name");                                       // 無此靜態方法
feature("name").scenario("name").given(() -> {}).perform();        // 完全不存在的 API
void test_method() { Feature.New("...").newScenario(); }           // 非 public → NoSuchMethodException
Feature.New("...").newScenario("AC1 - ...");                      // newScenario(String) 查找 pre-registered Rule，會拋 Rule not found
.Given("desc", () -> { })                                         // 型別錯誤：應為 Consumer<ScenarioEnvironment>
```

## ScenarioEnvironment geti() — String Values Only! (FC-3)

`ScenarioEnvironment.geti(key)` internally calls `Integer.parseInt((String) map.get(key))`.
If you put an `Integer` instead of a `String`, it throws `ClassCastException`.

```java
// ✅ CORRECT: Always put String values when using geti()
env.put("count", "5");
int count = env.geti("count");  // parseInt("5") → 5

env.put("total", String.valueOf(someInt));  // convert int to String
int total = env.geti("total");

// ❌ WRONG: Integer value → ClassCastException at geti()!
env.put("count", 5);            // puts Integer, not String
int count = env.geti("count");  // ClassCastException: Integer cannot be cast to String
```

**Rule**: When using `env.geti()` or `env.getl()`, the value stored via `env.put()` **MUST** be a `String`.

---

## ezSpec Test Method Visibility (FC-11)

`Feature.newScenario()` internally uses `Class.getMethod()` to find the calling test method.
`getMethod()` only finds **public** methods. Package-private methods cause `NoSuchMethodException`.

```java
// ✅ CORRECT: public method
@EzScenario
public void create_a_valid_product() {
    Feature.New("Create Product")
            .newScenario()
            // ...
            .Execute();
}

// ❌ WRONG: package-private → NoSuchMethodException at runtime!
@EzScenario
void create_a_valid_product() {  // missing 'public' keyword!
    Feature.New("Create Product")
            .newScenario()
            // ...
            .Execute();
}
```

**Error message when visibility is wrong**:
```
RuntimeException: tw.teddysoft.aiscrum.product.usecase.service.CreateProductServiceTest.create_a_valid_product()
Caused by: java.lang.NoSuchMethodException
```

**Rule**: All ezSpec test methods using `Feature.New().newScenario()` MUST be `public void`.

---

## ezSpec Lambda Signature (FC-6)

The Given/When/Then/And/But step methods accept `Consumer<ScenarioEnvironment>`, not `Runnable`.
Using `() -> {}` (no parameter) causes a compilation error.

```java
// ✅ CORRECT: Consumer<ScenarioEnvironment> — takes 'env' parameter
.Given("A user is authorized", env -> {
    env.put("userId", "user-123");
})
.When("The user creates a product", env -> {
    CqrsOutput<?> output = useCase.execute(input);
    env.put("output", output);
})
.Then("Product is created", env -> {
    // even if you don't use env, you MUST include the parameter
})

// ❌ WRONG: Runnable — no parameter → compilation error!
.Given("A user is authorized", () -> {      // ❌ type mismatch!
    // ...
})
.Then("Product is created", () -> {         // ❌ type mismatch!
    // ...
})
```

**Rule**: Always use `env -> { ... }` (with parameter), never `() -> { ... }` (without parameter).

---

## Contract Test Rules

| Contract Type | Abbreviation | Testing Strategy |
|---------------|--------------|------------------|
| Precondition | PRE-N | Test per method (each method has different PRE) |
| Postcondition | POST-N | Test per method (each method has different POST) |
| Getter Contract | GC-N | Test per getter |
| Class Invariant | INV-N | **Test once only** (aggregate-level shared) |

### Class Invariant Special Rule

- uContract calls `ensureInvariant()` at every public method entry
- If any operation (e.g., `rename()`) tests an INV, other operations don't need to
- Example: `rename_rejects_deleted_workflow()` tests INV-1 → `changeNote()` doesn't need INV-1

## Dual Profile Execution Commands

```bash
# Step 1: InMemory Profile
SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest={TestClass} -q

# Step 2: Outbox Profile
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest={TestClass} -q
```

### Verification Table (Required Output)

```
╔════════════════════════════════════════════════════════════════╗
║           DUAL-PROFILE TEST VERIFICATION TABLE                 ║
╠════════════════════════════════════════════════════════════════╣
║ Profile        │ Tests Run │ Passed │ Failed │ Status          ║
╠════════════════════════════════════════════════════════════════╣
║ test-inmemory  │     5     │   5    │   0    │ PASS            ║
║ test-outbox    │     5     │   5    │   0    │ PASS            ║
╠════════════════════════════════════════════════════════════════╣
║ OVERALL: BOTH PROFILES PASSED - Ready to proceed               ║
╚════════════════════════════════════════════════════════════════╝
```

## Key Testing Rules

- NO @ActiveProfiles on test classes
- Use @Autowired, never hardcode repositories
- Use @DirtiesContext(classMode = AFTER_EACH_TEST_METHOD)
- Extend BaseUseCaseTest for use case tests
- Use DateProvider.useFixedInstant() for deterministic time

---

## test-inmemory Profile 配置 (P1)

**必須創建 `application-test-inmemory.properties`**，否則 Spring Boot 會嘗試連接資料庫：

```properties
# src/test/resources/application-test-inmemory.properties

# Disable DataSource auto-configuration
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,\
  org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,\
  org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration

# Disable JPA
spring.data.jpa.repositories.enabled=false
```

**症狀（缺少此配置時）：**
```
Failed to determine a suitable driver class
Error creating bean with name 'flyway'
Error creating bean with name 'entityManagerFactory'
```

---

## BaseUseCaseTest Event Verification — Sync Polling Architecture Reference (P1)

> **⚠️ 本節為教學參考，不可直接複製**。新專案請使用 `references/templates/base-test-classes.md` 的 canonical template。
> 本節描述 sync polling 架構的原理，幫助理解事件驗證的底層機制。
>
> **設計決策**: 兩種事件驗證架構是 Dual-Profile Testing 的設計本質（皆為 active architecture），對應不同的 Spring Profile：
> - **InMemory profile (`test-inmemory`)**: 使用 sync polling（直接 `consumer.poll()`）— 無持久化，同步驗證即可
> - **Outbox profile (`test-outbox`)**: 使用 async consumer（`InternalInMemoryMessageConsumer` 背景 loop）— 模擬真實 pub/sub 流程
>
> 兩種架構同時存在不是冗餘，而是各自服務不同 profile 的正確選擇。

**生產環境 vs 測試環境的差異：**

| 環境 | 使用方式 | 說明 |
|------|---------|------|
| 生產環境 | pub/sub + `InternalInMemoryMessageConsumer` | 背景 loop 執行，自動 dispatch 到 Reactor |
| 測試環境 | 直接 `consumer.poll()` | 同步驗證事件，不需啟動背景 loop |

**測試環境直接使用 `poll()` 驗證事件：**

```java
public abstract class BaseUseCaseTest extends BaseSpringBootTest {

    @Autowired(required = false)
    protected InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker;

    protected InMemoryConsumer<DomainEventData> consumer;
    private int lastPolledIndex = 0;  // 🔑 追蹤已讀取的索引

    @BeforeEach
    public void setUpEventCapture() {
        this.lastPolledIndex = 0;
        if (inMemoryMessageBroker != null) {
            // 測試環境：建立 consumer 用於同步驗證（不需 InternalInMemoryMessageConsumer）
            this.consumer = new InMemoryConsumer<>(inMemoryMessageBroker);
        }
    }

    // ✅ 正確：從 lastPolledIndex 開始讀取
    protected List<DomainEvent> getCapturedEvents() {
        if (consumer == null) return new ArrayList<>();
        // 測試時直接呼叫 poll()，這是測試專用的驗證方式
        List<DomainEventData> polled = consumer.poll(lastPolledIndex, 1000);
        return polled.stream()
                .map(data -> (DomainEvent) DomainEventMapper.toDomain(data))
                .collect(Collectors.toList());
    }

    // ✅ 正確：更新索引跳過舊事件
    protected void clearCapturedEvents() {
        if (inMemoryMessageBroker != null) {
            lastPolledIndex = (int) inMemoryMessageBroker.size();
        }
    }
}
```

**⚠️ 重要區分：**
- **生產環境**：`poll()` 封裝在 `InternalInMemoryMessageConsumer` 內部，使用者不直接呼叫
- **測試環境**：直接呼叫 `consumer.poll()` 進行同步事件驗證是合理的

**常見錯誤：**
```java
// ❌ 錯誤：沒有使用 lastPolledIndex
protected List<DomainEvent> getCapturedEvents() {
    List<DomainEventData> polled = consumer.poll(0, 1000);  // 總是從頭讀取！
    // clearCapturedEvents() 更新了 lastPolledIndex，但這裡不用它
    // 導致 clearCapturedEvents() 後仍然返回舊事件
}
```

---

## SharedInfrastructureConfig vs VolatileRelayConfig vs CatchupRelayConfig (P1)

**避免 Bean 定義衝突：**

| Config | Profile | 負責 | Beans |
|--------|---------|------|-------|
| `SharedInfrastructureConfig` | inmemory/test-inmemory | Event Storage + Executor | `InMemoryMessageDb`, `InMemoryMessageDbClient`, `ExecutorService` |
| `VolatileRelayConfig` | inmemory/test-inmemory | Message Broker & Relay | `InMemoryMessageBroker`, `InMemoryProducer`, `MessageProducer`, `EzesVolatileRelay` |
| `SharedOutboxConfig` | outbox/test-outbox | JPA + MessageDbClient | `PgMessageDbClient` (via EntityManager + JpaRepositoryFactory) |
| `CatchupRelayConfig` | outbox/test-outbox | Message Broker & Relay | `InMemoryMessageBroker`, `InMemoryProducer`, `MessageProducer`, `EzesCatchUpRelay` |

```java
// ✅ 正確：SharedInfrastructureConfig 只負責 Event Storage + Executor
@Configuration
@Profile({"inmemory", "test-inmemory"})
public class SharedInfrastructureConfig {
    @Bean
    public InMemoryMessageDb inMemoryMessageDb() { ... }

    @Bean
    public InMemoryMessageDbClient inMemoryMessageDbClient(InMemoryMessageDb messageDb) { ... }

    @Bean
    public ExecutorService relayExecutor() { ... }

    // ❌ 不要在這裡定義 messageBroker, producer, relay！
    // 這些由 VolatileRelayConfig (inmemory) 或 CatchupRelayConfig (outbox) 負責
}
```

**症狀（Bean 衝突時）：**
```
BeanDefinitionOverrideException: Cannot register bean definition for bean 'inMemoryProducer'
since there is already [Root bean... factoryBeanName=sharedInfrastructureConfig] bound.
```
