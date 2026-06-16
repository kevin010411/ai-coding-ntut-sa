# Dual-Profile Test Infrastructure — Complete Reference

> **目的**：完整記錄 InMemory / Outbox 雙 profile 測試基礎設施的設計決策、事件流程、
> 以及每個設計如何預防已知的 7 個 failure causes。
>
> **來源**：從 `src/` 目錄的實際 working code 提取，非推測。
>
> **必讀時機**：產生 VolatileRelayConfig、CatchupRelayConfig、BaseUseCaseTest 時。

---

## 1. 架構總覽

### 事件流圖

```
┌─────────────────── InMemory Profile ───────────────────┐
│                                                         │
│  UseCase                                                │
│    │ repository.save(aggregate)                         │
│    ▼                                                    │
│  InMemoryOrmClient ──persist──▶ InMemoryOrmDb           │
│    │ (auto-append events)                               │
│    ▼                                                    │
│  InMemoryMessageDb                                      │
│    │                                                    │
│    ▼                                                    │
│  EzesVolatileRelay  ◄── relayExecutor.execute(relay)    │
│    │ (polls MessageDb, forwards to Producer)            │
│    ▼                                                    │
│  InMemoryMessageProducer                                │
│    │                                                    │
│    ▼                                                    │
│  InMemoryMessageBroker                                  │
│    │                                                    │
│    ▼                                                    │
│  InMemoryConsumer ──▶ NotifyFakeHandleAllEventsService  │
│                        (test event capture)             │
└─────────────────────────────────────────────────────────┘

┌─────────────────── Outbox Profile ─────────────────────┐
│                                                         │
│  UseCase                                                │
│    │ repository.save(aggregate)                         │
│    ▼                                                    │
│  JPA/Hibernate ──persist──▶ PostgreSQL (entity tables)  │
│    │ (OutboxMapper writes to messages table)            │
│    ▼                                                    │
│  PgMessageDb (message_store.messages table)             │
│    │                                                    │
│    ▼                                                    │
│  EzesCatchUpRelay  ◄── executor.execute(relay)          │
│    │ (polls PgMessageDb, UUID checkpoint)               │
│    ▼                                                    │
│  InMemoryMessageProducer                                │
│    │                                                    │
│    ▼                                                    │
│  InMemoryMessageBroker                                  │
│    │                                                    │
│    ▼                                                    │
│  InMemoryConsumer ──▶ NotifyFakeHandleAllEventsService  │
│                        (test event capture)             │
└─────────────────────────────────────────────────────────┘
```

### 關鍵差異

| 面向 | InMemory | Outbox |
|------|----------|--------|
| **MessageDb** | `InMemoryMessageDb` (記憶體) | `PgMessageDb` (PostgreSQL) |
| **Relay 類型** | `EzesVolatileRelay` | `EzesCatchUpRelay` |
| **Relay 啟動** | `relayExecutor.execute(relay)` (注入共用 ExecutorService) | `executor.execute(relay)` (自建 ExecutorService) |
| **Checkpoint** | 無（in-memory，每次 Context 重建自動重置） | UUID 路徑（磁碟檔案，避免跨 Context 殘留） |
| **Stale Event 處理** | 不需要（Context 重建清除一切） | 需要 drain + clear（200ms sleep） |
| **MessageDb 清理** | 不需要 | `DELETE FROM message_store.messages` + sequence reset |

---

## 2. Relay 生命週期矩陣

| 階段 | InMemory (VolatileRelay) | Outbox (CatchUpRelay) |
|------|--------------------------|----------------------|
| **建立** | `@Bean ezesVolatileRelay()` | `@Bean ezesCatchUpRelay()` |
| **啟動** | `relayExecutor.execute(relay)` | `executor.execute(relay)` |
| **輪詢** | 輪詢 `InMemoryMessageDb` | 輪詢 `PgMessageDb` |
| **Checkpoint** | 無 | `relay-checkpoint-{UUID}` (磁碟) |
| **Context 銷毀** | ExecutorService 被 GC → relay 停止 | ExecutorService 被 GC → relay 停止 |
| **新 Context** | 全新 relay + 全新 MessageDb | 全新 relay + UUID checkpoint → position 0 |
| **隔離保證** | `@DirtiesContext(AFTER_EACH_TEST_METHOD)` | `@DirtiesContext(AFTER_EACH_TEST_METHOD)` + DB cleanup |

---

## 3. 完整程式碼（6 個關鍵檔案）

### 3.1 VolatileRelayConfig.java (InMemory Profile)

**位置**: `src/main/java/${rootPackage}/common/io/springboot/config/connectionframe/VolatileRelayConfig.java`

```java
package tw.teddysoft.aiscrum.common.io.springboot.config.connectionframe;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.ezddd.data.EzesVolatileRelay;
import tw.teddysoft.ezddd.data.adapter.ezes.out.MessageDbToDomainEventDataConverter;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDbClient;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryMessageProducer;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryProducer;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageProducer;

import java.util.concurrent.ExecutorService;

@Configuration
@Profile({"inmemory", "test-inmemory"})
public class VolatileRelayConfig {

    @Bean
    public InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker() {
        return new InMemoryMessageBroker<>();
    }

    @Bean
    public InMemoryProducer<DomainEventData> inMemoryProducer(
            InMemoryMessageBroker<DomainEventData> broker) {
        return new InMemoryProducer<>(broker);
    }

    @Bean
    public MessageProducer<DomainEventData> messageProducer(
            InMemoryProducer<DomainEventData> producer) {
        return InMemoryMessageProducer.internal(producer);
    }

    // ⚠️ relayExecutor 由 SharedInfrastructureConfig 提供
    // ⚠️ 必須呼叫 execute() — EzesVolatileRelay 是 Runnable，不 execute 就不會輪詢
    @Bean
    public EzesVolatileRelay<DomainEventData> ezesVolatileRelay(
            InMemoryMessageDbClient messageDbClient,
            MessageProducer<DomainEventData> messageProducer,
            ExecutorService relayExecutor) {
        EzesVolatileRelay.RelayConfiguration<DomainEventData> configuration =
                EzesVolatileRelay.RelayConfiguration.of(
                        messageDbClient,
                        messageProducer,
                        new MessageDbToDomainEventDataConverter());
        EzesVolatileRelay<DomainEventData> relay = new EzesVolatileRelay<>(configuration);
        relayExecutor.execute(relay);  // ← 關鍵：auto-start relay
        return relay;
    }
}
```

### 3.2 CatchupRelayConfig.java (Outbox Profile)

**位置**: `src/main/java/${rootPackage}/common/io/springboot/config/connectionframe/CatchupRelayConfig.java`

```java
package tw.teddysoft.aiscrum.common.io.springboot.config.connectionframe;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.ezddd.data.EzesCatchUpRelay;
import tw.teddysoft.ezddd.data.adapter.ezes.out.MessageDbToDomainEventDataConverter;
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryMessageProducer;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryProducer;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageProducer;

import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Configuration
@Profile({"outbox", "test-outbox"})
public class CatchupRelayConfig {

    @Bean
    public InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker() {
        return new InMemoryMessageBroker<>();
    }

    @Bean
    public InMemoryProducer<DomainEventData> inMemoryProducer(
            InMemoryMessageBroker<DomainEventData> broker) {
        return new InMemoryProducer<>(broker);
    }

    @Bean
    public MessageProducer<DomainEventData> messageProducer(
            InMemoryProducer<DomainEventData> producer) {
        return InMemoryMessageProducer.internal(producer);
    }

    // ⚠️ UUID checkpoint：防止 Failure #6 (stale checkpoint)
    // ⚠️ executor.execute(relay)：auto-start relay
    @Bean
    public EzesCatchUpRelay<DomainEventData> ezesCatchUpRelay(
            PgMessageDbClient pgMessageDbClient,
            MessageProducer<DomainEventData> messageProducer) {
        ExecutorService executor = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
        Path checkpointPath = Path.of(System.getProperty("java.io.tmpdir"),
                "relay-checkpoint-" + UUID.randomUUID());  // ← Failure #6 fix
        EzesCatchUpRelay.RelayConfiguration<DomainEventData> configuration =
                EzesCatchUpRelay.RelayConfiguration.of(
                        pgMessageDbClient,
                        messageProducer,
                        checkpointPath,
                        new MessageDbToDomainEventDataConverter());
        EzesCatchUpRelay<DomainEventData> relay = new EzesCatchUpRelay<>(configuration);
        executor.execute(relay);  // ← auto-start relay
        return relay;
    }
}
```

### 3.3 SharedInfrastructureConfig.java (InMemory 共用基礎設施)

**位置**: `src/main/java/${rootPackage}/common/io/springboot/config/SharedInfrastructureConfig.java`

```java
package tw.teddysoft.aiscrum.common.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDb;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDbClient;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Configuration
@Profile({"inmemory", "test-inmemory"})
public class SharedInfrastructureConfig {

    @Bean
    public InMemoryMessageDb inMemoryMessageDb() {
        return new InMemoryMessageDb();
    }

    @Bean
    public InMemoryMessageDbClient inMemoryMessageDbClient(InMemoryMessageDb messageDb) {
        return new InMemoryMessageDbClient(messageDb);
    }

    // VolatileRelayConfig 注入此 ExecutorService 來啟動 relay
    @Bean
    public ExecutorService relayExecutor() {
        return Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
    }
}
```

### 3.4 SharedOutboxConfig.java (Outbox 共用基礎設施)

**位置**: `src/main/java/${rootPackage}/common/io/springboot/config/SharedOutboxConfig.java`

```java
package tw.teddysoft.aiscrum.common.io.springboot.config;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;

@Configuration
@Profile({"outbox", "test-outbox"})
@EnableTransactionManagement
@EnableJpaRepositories(basePackages = {
        "${rootPackage}",
        "tw.teddysoft.ezddd.data.io.ezes.store"
})
@EntityScan(basePackages = {
        "${rootPackage}",
        "tw.teddysoft.ezddd.data.io.ezes.store"
})
public class SharedOutboxConfig {

    @PersistenceContext
    private EntityManager entityManager;

    @Bean
    public PgMessageDbClient pgMessageDbClient() {
        JpaRepositoryFactory factory = new JpaRepositoryFactory(entityManager);
        return factory.getRepository(PgMessageDbClient.class);
    }
}
```

### 3.5 BaseUseCaseTest.java (測試基底)

**位置**: `src/test/java/${rootPackage}/test/base/BaseUseCaseTest.java`

```java
package tw.teddysoft.aiscrum.test.base;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.aiscrum.common.NotifyFakeHandleAllEventsService;
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.InMemoryConsumer;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.internal.InternalInMemoryMessageConsumer;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageProducer;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

// ⚠️ AFTER_EACH_TEST_METHOD：每個測試方法後銷毀 Spring Context
//    解決 Failure #5 (Singleton Trap) — 確保每個測試有全新的 relay 實例
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public abstract class BaseUseCaseTest extends BaseSpringBootTest {

    @Autowired
    protected InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker;

    @Autowired
    protected MessageProducer<DomainEventData> messageProducer;

    // ⚠️ 不在這裡建立 relay！VolatileRelayConfig/CatchupRelayConfig 管理 relay 生命週期
    // 建立第二個 relay = Failure #5 (double relay → duplicate event delivery)

    @Autowired(required = false)
    protected PgMessageDbClient pgMessageDbClient;

    @Autowired(required = false)
    protected JdbcTemplate jdbcTemplate;

    @Value("${spring.profiles.active:test-inmemory}")
    protected String activeProfile;

    protected NotifyFakeHandleAllEventsService notifyFakeHandleAllEventsService;
    protected InternalInMemoryMessageConsumer notifyHandleAllEventsConsumer;
    protected InMemoryConsumer<DomainEventData> inMemoryConsumer;
    protected ExecutorService executorService;

    /**
     * 子類別必須在 @BeforeEach 中呼叫此方法。
     *
     * 執行順序：
     * 1. [Outbox only] 清除 messages 表 + 重設 sequence
     * 2. 建立事件捕獲 consumer
     * 3. [Outbox only] Drain stale events（Failure #7 fix）
     */
    protected void setUpEventCapture() {
        System.out.println("==> Running test with profile: " + activeProfile);

        // [Outbox only] 清除前一個測試殘留的 messages
        if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("DELETE FROM message_store.messages");
                jdbcTemplate.execute("ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1");
                System.out.println("Cleaned up message_store.messages table and reset sequence");
            } catch (Exception e) {
                System.err.println("Could not clean messages table: " + e.getMessage());
            }
        }

        notifyFakeHandleAllEventsService = new NotifyFakeHandleAllEventsService();

        inMemoryConsumer = new InMemoryConsumer<>(inMemoryMessageBroker);
        notifyHandleAllEventsConsumer = new InternalInMemoryMessageConsumer(
                notifyFakeHandleAllEventsService, inMemoryConsumer);
        executorService = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
        executorService.submit(notifyHandleAllEventsConsumer);
        // ⚠️ Relay 已由 VolatileRelayConfig/CatchupRelayConfig 啟動
        // 不要在這裡啟動第二個 relay → Failure #5

        // [Outbox only] Failure #7 fix：UUID checkpoint 使 relay 從 position 0 開始，
        // 可能在 DB cleanup 之前已轉發舊事件。等待消費完畢再清除。
        if ("test-outbox".equals(activeProfile)) {
            try { Thread.sleep(200); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            notifyFakeHandleAllEventsService.clearHandledEvents();
        }
    }

    /**
     * 子類別必須在 @AfterEach 中呼叫此方法。
     *
     * CRITICAL: For outbox profile, messages MUST be cleaned in tearDown (not just setUp).
     * Reason: CatchUpRelay starts during Spring Context init (@Bean), which is BEFORE @BeforeEach.
     * If messages are only cleaned in setUp, the new relay has already read stale messages
     * from the previous test before cleanup can happen.
     *
     * @see testing-patterns.md Error Pattern #7
     */
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

        // CRITICAL: Clean outbox messages BEFORE Context is destroyed,
        // so the next test's CatchUpRelay starts with an empty message table.
        if ("test-outbox".equals(activeProfile) && jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("DELETE FROM message_store.messages");
                jdbcTemplate.execute("ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1");
                System.out.println("tearDown: Cleaned up message_store.messages table");
            } catch (Exception e) {
                System.err.println("tearDown: Could not clean messages table: " + e.getMessage());
            }
        }
    }

    protected void clearCapturedEvents() {
        if (notifyFakeHandleAllEventsService != null) {
            notifyFakeHandleAllEventsService.clearHandledEvents();
        }
    }
}
```

### 3.6 NotifyFakeHandleAllEventsService.java (事件捕獲)

**位置**: `src/test/java/${rootPackage}/common/NotifyFakeHandleAllEventsService.java`

```java
package tw.teddysoft.aiscrum.common;

import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;

import java.util.ArrayList;
import java.util.List;

public class NotifyFakeHandleAllEventsService implements Reactor<DomainEventData> {
    private final List<InternalDomainEvent> handledDomainEvents = new ArrayList<>();

    @Override
    public void execute(DomainEventData message) {
        if (message != null) {
            this.handledDomainEvents.add(DomainEventMapper.toDomain(message));
        }
    }

    public long handledEventTimes(Class<?> clazz) {
        return handledDomainEvents.stream().filter(d -> d.getClass().isAssignableFrom(clazz)).count();
    }

    public int getHandledEventsSize() {
        return handledDomainEvents.size();
    }

    public InternalDomainEvent getLastHandledEvent() {
        return handledDomainEvents.getLast();
    }

    public List<InternalDomainEvent> getHandledEvents() {
        return handledDomainEvents;
    }

    public void clearHandledEvents() {
        handledDomainEvents.clear();
    }
}
```

---

## 4. Failure Prevention 對照表

每個設計決策都對應防止一個或多個已知的 failure cause。

| # | Failure Cause | 症狀 | 預防措施 | 實作位置 |
|---|--------------|------|---------|---------|
| 1 | **Hardcoded Repository** | 編譯錯誤或 bean not found | Spring DI `@Autowired` | BaseUseCaseTest |
| 2 | **@ActiveProfiles** | profile 無法切換 | 禁止使用，由環境變數控制 | BaseSpringBootTest |
| 3 | **缺少 @DirtiesContext** | 測試間共享 stale state | `AFTER_EACH_TEST_METHOD` | BaseUseCaseTest |
| 4 | **缺少 setUpEventCapture()** | 事件捕獲未初始化 | protected 方法，子類必須呼叫 | BaseUseCaseTest |
| 5 | **Double Relay (Singleton Trap)** | 每個事件被投遞兩次 | Relay 只在 Config 中啟動，BaseUseCaseTest 不啟動 | VolatileRelayConfig + BaseUseCaseTest |
| 6 | **Stale Checkpoint** | Outbox relay 看不到新事件 | UUID checkpoint 路徑 | CatchupRelayConfig |
| 7 | **Stale Event Leak** | 收到前一測試的殘留事件 | sleep 200ms + clearHandledEvents() | BaseUseCaseTest |
| — | **Relay 未啟動** | 事件永遠不投遞（靜默失敗） | `relayExecutor.execute(relay)` | VolatileRelayConfig |

### Failure #5 (Double Relay) 詳解

```
❌ 錯誤：Config 啟動 relay + BaseUseCaseTest 也啟動 relay
   → 兩個 relay 同時輪詢 MessageDb
   → 每個事件被轉發兩次到 MessageBroker
   → NotifyFakeHandleAllEventsService 收到 2x 事件
   → handledEventsSize() == 2 (預期 1) → 測試失敗

✅ 正確：只在 Config 啟動 relay，BaseUseCaseTest 只啟動 consumer
   → 單一 relay 輪詢 MessageDb
   → 每個事件被轉發一次
   → handledEventsSize() == 1 ✓
```

### Failure #6 → #7 連鎖 (Outbox Only)

```
測試 A 完成
  → messages 表有 events
  → @DirtiesContext 銷毀 Spring Context
  ─────────────────────────────────────
測試 B 開始
  → 新 Spring Context 建立
  → CatchupRelayConfig 建立新 relay

  [Failure #6 如果用固定 checkpoint]
  → relay 讀到舊 checkpoint position = 5
  → messages 表被清除後 sequence restart from 1
  → relay 等待 position > 5 的事件 → 永遠等不到

  [Fix: UUID checkpoint]
  → relay 用新 UUID checkpoint → position = 0
  → relay 從 position 0 開始讀

  [Failure #7 因為 UUID fix]
  → relay 在 setUpEventCapture() 之前就開始讀
  → 讀到測試 A 殘留在 messages 表的舊事件
  → consumer 收到不屬於測試 B 的事件

  [Fix: drain + clear]
  → setUpEventCapture() 先 sleep 200ms 等舊事件被消費
  → 再 clearHandledEvents() 清除
  → 測試 B 的 assertions 只看到自己的事件
```

---

## 5. 常見陷阱

| 症狀 | 原因 | 預防方式 | 相關 Failure |
|------|------|---------|-------------|
| 第一個測試通過，後續失敗 | Singleton Trap — relay 無法重啟 | `@DirtiesContext(AFTER_EACH_TEST_METHOD)` | #5 |
| 事件數量是預期的 2 倍 | Double Relay — Config + Test 都啟動 | 只在 Config 啟動 relay | #5 |
| 事件驗證超時 (timeout) | Relay 未啟動 | `relayExecutor.execute(relay)` | — |
| Outbox 測試看不到事件 | Stale checkpoint 指向已清除的 position | UUID checkpoint | #6 |
| Outbox 第一個 assertion 收到多餘事件 | Stale events 從前一測試洩漏 | sleep + clearHandledEvents() | #7 |
| `No qualifying bean of type 'ExecutorService'` | SharedInfrastructureConfig 未載入 | 確認 `@Profile` 包含 `test-inmemory` | — |
| `Table 'messages' doesn't exist` | Outbox profile 用了 `create-drop` | 必須保持 `ddl-auto=update` | — |

---

## 6. 測試時序圖

### InMemory Profile 測試執行序列

```
@DirtiesContext 建立新 Spring Context
  │
  ├─ SharedInfrastructureConfig
  │   ├─ InMemoryMessageDb (new)
  │   ├─ InMemoryMessageDbClient (new)
  │   └─ ExecutorService relayExecutor (new)
  │
  ├─ VolatileRelayConfig
  │   ├─ InMemoryMessageBroker (new)
  │   ├─ InMemoryProducer (new)
  │   ├─ MessageProducer (new)
  │   └─ EzesVolatileRelay (new + auto-started)  ◄── relayExecutor.execute(relay)
  │
  ├─ @BeforeEach
  │   └─ setUpEventCapture()
  │       ├─ NotifyFakeHandleAllEventsService (new)
  │       ├─ InMemoryConsumer (new, subscribes to broker)
  │       └─ executorService.submit(consumer)  ◄── consumer 開始監聽
  │
  ├─ @Test
  │   ├─ useCase.execute(...)
  │   │   └─ repository.save(aggregate)
  │   │       └─ InMemoryMessageDb ← events appended
  │   │           └─ VolatileRelay polls → MessageProducer → Broker → Consumer
  │   │               └─ NotifyFakeHandleAllEventsService.handledDomainEvents ← event
  │   └─ Awaitility.await()... → verify event captured
  │
  └─ @AfterEach
      └─ tearDownEventCapture()
          └─ executorService.shutdownNow()
              └─ consumer 停止（relay 隨 Context 銷毀而停止）
```

### Outbox Profile 測試執行序列

```
@DirtiesContext 建立新 Spring Context
  │
  ├─ SharedOutboxConfig
  │   └─ PgMessageDbClient (new JPA proxy)
  │
  ├─ CatchupRelayConfig
  │   ├─ InMemoryMessageBroker (new)
  │   ├─ InMemoryProducer (new)
  │   ├─ MessageProducer (new)
  │   └─ EzesCatchUpRelay (new + auto-started)
  │       ├─ UUID checkpoint → position 0
  │       └─ executor.execute(relay)  ◄── relay 開始輪詢 PgMessageDb
  │           └─ ⚠️ 可能讀到前一測試殘留事件 (Failure #7)
  │
  ├─ @BeforeEach
  │   └─ setUpEventCapture()
  │       ├─ DELETE FROM message_store.messages  ◄── 清除殘留
  │       ├─ RESTART sequence
  │       ├─ NotifyFakeHandleAllEventsService (new)
  │       ├─ InMemoryConsumer (new)
  │       ├─ executorService.submit(consumer)
  │       ├─ Thread.sleep(200)  ◄── Failure #7 fix: 等待 stale events 被消費
  │       └─ clearHandledEvents()  ◄── 清除 stale events
  │
  ├─ @Test
  │   ├─ useCase.execute(...)
  │   │   └─ repository.save(aggregate)
  │   │       └─ JPA persist → PostgreSQL → messages table
  │   │           └─ CatchUpRelay polls → MessageProducer → Broker → Consumer
  │   │               └─ NotifyFakeHandleAllEventsService.handledDomainEvents ← event
  │   └─ Awaitility.await()... → verify event captured
  │
  └─ @AfterEach
      └─ tearDownEventCapture()
          └─ executorService.shutdownNow()
```

---

## 7. 配置檔案依賴關係

```
SharedInfrastructureConfig ──provides──▶ ExecutorService (relayExecutor)
        │                                       │
        │ provides                               │ injected into
        ▼                                        ▼
InMemoryMessageDbClient ──────────▶ VolatileRelayConfig
                                        │
                                        │ provides
                                        ▼
                              InMemoryMessageBroker ──▶ BaseUseCaseTest (consumer)


SharedOutboxConfig ──provides──▶ PgMessageDbClient
                                        │
                                        │ injected into
                                        ▼
                              CatchupRelayConfig
                                        │
                                        │ provides
                                        ▼
                              InMemoryMessageBroker ──▶ BaseUseCaseTest (consumer)
```

---

## 8. Architecture Decision Box ⭐⭐⭐

> **Canonical Pattern**: Config auto-start relay（NEW 架構）。
> BaseUseCaseTest 中手動建立 relay（OLD 架構）**已棄用**。

### NEW vs OLD 架構對照

| 面向 | OLD (棄用) | NEW (Canonical) ✅ |
|------|-----------|-------------------|
| **Relay 啟動位置** | `BaseUseCaseTest.startNewRelayInstance()` | Config `@Bean` 方法中 `relayExecutor.execute(relay)` |
| **每測試新 relay** | 手動 new + execute | `@DirtiesContext(AFTER_EACH_TEST_METHOD)` 重建 Spring Context |
| **VolatileRelayConfig** | 只建 relay，不啟動 | **建立 + 啟動**（`relayExecutor.execute(relay)`） |
| **BaseUseCaseTest 職責** | 建 relay + consumer | **只建 consumer**，不碰 relay |
| **Stale event drain** | 不需要 | `sleep(200) + clearHandledEvents()`（Outbox only） |

### 為什麼 NEW 架構是正確的

1. **單一責任**：Config 管理 relay 生命週期，Test 只管事件捕獲
2. **避免 Double Relay**：如果 Config 和 Test 都啟動 relay → 每個事件被投遞兩次
3. **`@DirtiesContext` 自然隔離**：每個測試重建 Context = 自然得到新 relay，不需手動管理

### ⚠️ AI 產生程式碼時的判斷規則

```
如果看到 BaseUseCaseTest 中有 `startNewRelayInstance()` 或
手動建立 `EzesVolatileRelay` → 這是 OLD 架構的殘留，不要複製。

如果看到 VolatileRelayConfig 的 @Bean 方法只 return relay 但不 execute → BUG。
```

---

## 9. TestSuite — Global Suite with @SelectPackages ⭐⭐⭐

> **Canonical Pattern**: 全專案只有兩個 TestSuite（`InMemoryTestSuite` + `OutboxTestSuite`），
> 使用 **inner class ProfileSetter** + **`@SelectPackages` 按 aggregate package 自動掃描測試類別**。

### 9.1 為什麼用 Global Suite + @SelectPackages

| 模式 | 優劣 |
|------|------|
| ✅ **Global Suite + `@SelectPackages`** | 全專案只有 2 個 suite 檔案；新增 use case 不需修改；新增 aggregate 只加一行 package |
| ❌ Per-use-case Suite + `@SelectClasses` | N 個 use case = 2N 個 suite 檔案；每次新增 use case 都要新建 2 個檔案 |
| ❌ Standalone ProfileSetter | 額外檔案、與 suite 分離、init-project 階段無 aggregate 可引用 |

### 9.2 Working Code 範例

**InMemoryTestSuite (from `src/test/`)**：

```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("In-Memory Tests - Fast Execution")
@SelectClasses({
        InMemoryTestSuite.ProfileSetter.class
})
@SelectPackages({
        "tw.teddysoft.aiscrum.pbi",
        "tw.teddysoft.aiscrum.product",
        "tw.teddysoft.aiscrum.scrumteam",
        "tw.teddysoft.aiscrum.sprint",
        "tw.teddysoft.aiscrum.workflow"
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

**OutboxTestSuite (from `src/test/`)**：

```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("Outbox Pattern Tests - PostgreSQL Database")
@SelectClasses({
        OutboxTestSuite.ProfileSetter.class
})
@SelectPackages({
        "tw.teddysoft.aiscrum.pbi",
        "tw.teddysoft.aiscrum.product",
        "tw.teddysoft.aiscrum.scrumteam",
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
```

### 9.3 命名慣例

| 項目 | 格式 | 範例 |
|------|------|------|
| **Suite 類別名** | `InMemoryTestSuite` / `OutboxTestSuite` | 全專案各一個 |
| **Package** | `${rootPackage}.test.suite` | `tw.teddysoft.aiscrum.test.suite` |
| **目錄** | `src/test/java/.../test/suite/` | 只有 2 個檔案 |

### 9.4 何時產生 / 更新 TestSuite

| 時機 | 動作 |
|------|------|
| **init-project** | **不產生** TestSuite（尚無 aggregate，等第一次 PF 執行） |
| **第一次 PF 執行** | 建立 `InMemoryTestSuite` + `OutboxTestSuite`，`@SelectPackages` 加入第一個 aggregate package |
| **後續 PF 執行（同一 Aggregate）** | 不需修改 TestSuite |
| **後續 PF 執行（新 Aggregate）** | 在兩個 TestSuite 的 `@SelectPackages` 加入新 aggregate package |

---

## 10. Concrete Test Class Example ⭐⭐⭐

> **來源**：`src/test/java/.../product/usecase/service/CreateProductServiceTest.java`（working code）

### 10.1 完整範例

```java
package ${rootPackage}.${aggregate}.usecase.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import ${rootPackage}.${aggregate}.entity.*;
import ${rootPackage}.${aggregate}.usecase.port.in.Create${Aggregate}UseCase;
import ${rootPackage}.common.entity.DateProvider;
import ${rootPackage}.test.base.BaseUseCaseTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;
import tw.teddysoft.ezspec.keyword.Feature;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class Create${Aggregate}ServiceTest extends BaseUseCaseTest {

    @Autowired
    private Create${Aggregate}UseCase create${Aggregate}UseCase;

    @Autowired
    private Repository<${Aggregate}, ${Aggregate}Id> ${aggregate}Repository;

    private Feature feature;

    @BeforeEach
    void setUp() {
        DateProvider.useSystemTime();
        setUpEventCapture();           // ← 必須呼叫！初始化事件捕獲 consumer
        feature = Feature.New("Create${Aggregate}", "Verify Create${Aggregate} use case");
    }

    @AfterEach
    void tearDown() {
        tearDownEventCapture();         // ← 必須呼叫！關閉 consumer executor
    }

    @EzScenario
    public void AC1_create_${aggregate}_successfully() {
        feature.newScenario()
                .Given("valid input", env -> {
                    // 準備 input
                })
                .When("execute use case", env -> {
                    // 執行 use case
                })
                .Then("request succeeds", env -> {
                    // 驗證 output
                })
                .And("domain event is published", env -> {
                    // ⚠️ 使用 Awaitility 等待非同步事件
                    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                                .isEqualTo(1);
                    });
                })
                .Execute();
    }
}
```

### 10.2 關鍵標註

| 行 | 標註 | 說明 |
|----|------|------|
| `@DirtiesContext(AFTER_EACH_TEST_METHOD)` | 隔離 | 每個測試有新的 Spring Context（含新 relay） |
| `setUpEventCapture()` | 必須 | 初始化 consumer，**不建 relay**（relay 由 Config 管理） |
| `tearDownEventCapture()` | 必須 | 關閉 consumer 的 ExecutorService |
| `await().atMost(10, TimeUnit.SECONDS)` | 事件驗證 | 事件投遞是非同步的，必須用 Awaitility 等待 |
| `notifyFakeHandleAllEventsService` | 繼承自 BaseUseCaseTest | 事件捕獲服務，在 `setUpEventCapture()` 中初始化 |

---

## 11. Application Properties（Working Code）

### 11.1 application-test-inmemory.properties

```properties
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,\
  org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,\
  org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration

spring.data.jpa.repositories.enabled=false
```

> **`spring.data.jpa.repositories.enabled=false`**：InMemory profile 必須禁用 JPA repository auto-detection，
> 否則 Spring 會嘗試初始化 JPA 相關 bean（如 `EntityManagerFactory`）而失敗。

### 11.2 application-test-outbox.properties

```properties
# PostgreSQL — port 和 dbName 從 .dev/project-config.json 讀取
spring.datasource.url=jdbc:postgresql://localhost:${testDbPort}/${dbName}?currentSchema=message_store
spring.datasource.username=postgres
spring.datasource.password=${dbPassword}
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.data.jpa.repositories.enabled=true

spring.flyway.enabled=false

messagestore.postgres.url=${spring.datasource.url}
messagestore.postgres.user=${spring.datasource.username}
messagestore.postgres.password=${spring.datasource.password}
```

> **`spring.jpa.hibernate.ddl-auto=update`**：禁止改為 `create-drop`，否則會刪除 `messages` 表。
> **`spring.data.jpa.repositories.enabled=true`**：Outbox profile 必須啟用 JPA repository。

---

## 12. 生成 Checklist（AI 產生測試基礎設施時依序檢查）

| # | 步驟 | 檢查 |
|---|------|------|
| 1 | 確認 `SharedInfrastructureConfig.java` 存在 | 包含 `InMemoryMessageDb`、`InMemoryMessageDbClient`、`ExecutorService relayExecutor` |
| 2 | 確認 `SharedOutboxConfig.java` 存在 | 包含 `PgMessageDbClient`、`@EnableJpaRepositories`、`@EntityScan` |
| 3 | 確認 `VolatileRelayConfig.java` 存在 | `relayExecutor.execute(relay)` ← **必須 auto-start** |
| 4 | 確認 `CatchupRelayConfig.java` 存在 | UUID checkpoint + `executor.execute(relay)` |
| 5 | 確認 `BaseUseCaseTest.java` 不建 relay | 只建 consumer，**不呼叫** `relayExecutor.execute()` |
| 6 | 建立 Concrete Test Class | `extends BaseUseCaseTest`、`@BeforeEach` → `setUpEventCapture()`、`@AfterEach` → `tearDownEventCapture()` |
| 7 | 建立 InMemory TestSuite | Inner class ProfileSetter + `@SelectClasses` 明確列出 |
| 8 | 建立 Outbox TestSuite | Inner class ProfileSetter + `@SelectClasses` 明確列出 |
| 9 | 執行 InMemory 測試 | `SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest={TestClass}` |
| 10 | 執行 Outbox 測試 | `SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest={TestClass}` |

---

## 相關文件

- **Singleton Trap 教訓**: `rules/testing-patterns.md` §DirtiesContext（EzesVolatileRelay 是 stateful Runnable，shutdownNow 後不可復用）
- **Outbox Pattern 模板**: `.claude/skills/ezddd-java/references/patterns/infrastructure/outbox.md`
- **Base Test Classes 模板**: `.claude/skills/ezddd-java/references/templates/base-test-classes.md`
- **Init Project 模板**: `.claude/skills/ezddd-java/references/init-project/templates.md`
- **Test Suite 模板**: `.claude/skills/ezddd-java/references/templates/test-suites.md`
- **ADR-021**: Profile-Based Testing 規範
- **ADR-049**: Profile-Based Testing Architecture
