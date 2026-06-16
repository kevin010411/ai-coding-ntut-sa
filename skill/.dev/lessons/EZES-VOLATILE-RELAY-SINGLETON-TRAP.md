# EzesVolatileRelay Singleton Trap

## 問題描述

`EzesVolatileRelay` 是一個有狀態的 `Runnable`，當被 `shutdownNow()` 中斷後，內部的 `running` 旗標會變成 `false`，導致無法重新啟動。

## 症狀

- **第一個測試**：正常通過
- **第二個測試及之後**：事件驗證失敗（事件沒有被轉發）

```
Test 1: ✅ PASS (relay 正常運行)
Test 2: ❌ FAIL (relay 不再運行，事件驗證超時)
Test 3: ❌ FAIL (同上)
```

## 根本原因

```java
// 錯誤的寫法：使用 @Autowired 注入 singleton
@Autowired
private EzesVolatileRelay<DomainEventData> relay;  // ❌ Singleton!

@BeforeEach
void setUp() {
    executorService.execute(relay);  // ❌ 第二次啟動無效
}

@AfterEach
void tearDown() {
    executorService.shutdownNow();   // 中斷後 relay.running = false
}
```

**問題**：`EzesVolatileRelay` 內部有 `volatile boolean running = true`，一旦被中斷就變成 `false`，不會自動重置。

## 解決方案

**在 `BaseUseCaseTest.setUpEventCapture()` 中每次建立新的 relay 實例**。

### ⚠️ 重要更新 (2026-01-13)：BaseUseCaseTest 使用 @BeforeEach/@AfterEach

`BaseUseCaseTest` 的 `setUpEventCapture()` 和 `tearDownEventCapture()` 已經標記為 `@BeforeEach` 和 `@AfterEach`。

**繼承時不需要（也不應該）手動呼叫這些方法！**

```java
// ✅ 正確：繼承 BaseUseCaseTest，不要手動呼叫 setUpEventCapture()
@DirtiesContext(classMode = ClassMode.BEFORE_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {

    @BeforeEach
    void setUp() {
        DateProvider.useSystemTime();
        // ⛔ 不要呼叫 setUpEventCapture() - 父類別的 @BeforeEach 已經呼叫
    }

    // ⛔ 不要呼叫 tearDownEventCapture() - 父類別的 @AfterEach 已經呼叫
}

// ❌ 錯誤：手動呼叫導致重複 relay 實例
public class WrongTest extends BaseUseCaseTest {

    @BeforeEach
    void setUp() {
        setUpEventCapture();  // ❌ 重複呼叫！父類別已經呼叫過
    }

    @AfterEach
    void tearDown() {
        tearDownEventCapture();  // ❌ 重複呼叫！
    }
}
```

**為什麼手動呼叫會出錯：**
1. 父類別 `@BeforeEach` 已經呼叫 `setUpEventCapture()` → 建立 relay #1
2. 子類別 `setUp()` 又呼叫 `setUpEventCapture()` → 建立 relay #2
3. 結果：2 個 relay 都在處理事件 → 事件數量翻倍
```

### BaseUseCaseTest 內部實現

```java
// BaseUseCaseTest.java
@Autowired(required = false)
protected InMemoryMessageDbClient inMemoryMessageDbClient;  // InMemory profile

@Autowired(required = false)
protected PgMessageDbClient pgMessageDbClient;  // Outbox profile

@Autowired
protected MessageProducer<DomainEventData> messageProducer;

protected void setUpEventCapture() {
    // ...其他設置...
    startNewRelayInstance();  // 每次建立新實例
}

private void startNewRelayInstance() {
    if (inMemoryMessageDbClient != null) {
        // InMemory profile: use EzesVolatileRelay
        EzesVolatileRelay.RelayConfiguration<DomainEventData> configuration =
                EzesVolatileRelay.RelayConfiguration.of(
                        inMemoryMessageDbClient,
                        messageProducer,
                        new MessageDbToDomainEventDataConverter());
        EzesVolatileRelay<DomainEventData> relay = new EzesVolatileRelay<>(configuration);
        executorService.execute(relay);  // ✅ 新實例，running = true
    } else if (pgMessageDbClient != null) {
        // Outbox profile: use EzesCatchUpRelay
        // ...類似處理...
    }
}
```

## 關鍵點

1. **不要 `@Autowired` relay** - 避免使用 singleton
2. **relay 建立集中在 `BaseUseCaseTest.setUpEventCapture()`** - DRY 原則，避免每個測試類別重複
3. **⛔ 不要手動呼叫 `setUpEventCapture()` / `tearDownEventCapture()`** - 父類別的 @BeforeEach/@AfterEach 已經處理
4. **使用 `@Autowired(required = false)`** - 因為 InMemory 和 Outbox profile 用不同的 client
5. **使用 `@DirtiesContext(classMode = BEFORE_EACH_TEST_METHOD)`** - 確保每個測試方法有乾淨的 Spring Context

## 適用範圍

任何實現 `Runnable` 且有內部狀態（如 `running` 旗標）的類別，都可能有類似問題：

- `EzesVolatileRelay`
- `EzesCatchUpRelay`
- 其他有 `while(running)` 模式的背景任務

## 經驗教訓

> **有狀態的 Runnable + Singleton = 測試隔離失敗**
>
> 在測試中，永遠不要重用有內部狀態的 Runnable 實例。

## 發現日期

2026-01-12

## 相關文件

- `.ai/tech-stacks/java-ezddd-spring/examples/use-case-test-example.md`
- `src/test/java/.../test/base/BaseUseCaseTest.java` - relay 建立的實際實現
- `CreateProductServiceTest.java` - 測試類別範例
