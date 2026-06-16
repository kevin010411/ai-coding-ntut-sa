# AI Prompt for Test Case Generation (ezapp 2.0.0)

## ⚠️ Version Notice

**ezapp 2.0.0 推薦架構**: 使用 Spring DI 注入，不再手動建立 Repository 和 MessageBus

**本文件狀態**: 僅供參考舊版實作方式，新專案請使用 Spring DI 注入模式

## Context
When generating test cases for use cases in this ai-kanban project, follow the patterns for proper integration with the ezddd framework.

## Recommended: ezapp 2.0.0 Spring DI Injection Pattern

### 推薦做法：使用 Spring DI 注入

```java
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.ezddd.data.io.ezoutbox.InMemoryOrmDb;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;
import [rootPackage].[aggregate].entity.[Aggregate];
import [rootPackage].[aggregate].entity.[Aggregate]Id;
import [rootPackage].[aggregate].usecase.port.out.[Aggregate]Data;
import [rootPackage].[aggregate].usecase.port.in.Create[Aggregate]UseCase;

@SpringBootTest
// NO @ActiveProfiles — use TestSuite ProfileSetter pattern (ADR-021)
// @DirtiesContext is inherited from BaseUseCaseTest — no need to repeat
// @TestMethodOrder is NOT needed (Rule 13 removed) — @DirtiesContext ensures test isolation
public class Create[Aggregate]ServiceTest extends BaseUseCaseTest {

    @Autowired
    private Create[Aggregate]UseCase useCase;  // 由 Spring DI 注入

    @Autowired
    private Repository<[Aggregate], [Aggregate]Id> repository;  // 由 Spring DI 注入

    @Autowired(required = false)  // null in Outbox profile (no InMemoryOrmDb bean)
    private InMemoryOrmDb<[Aggregate]Data> [aggregate]OrmDb;

    private Feature feature;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();       // 🔴 必須呼叫：初始化事件捕獲 consumer
        DateProvider.useSystemTime();
        if ([aggregate]OrmDb != null) [aggregate]OrmDb.clear();
        feature = Feature.New("Create[Aggregate]", "Create a new [aggregate]");
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture();    // 🔴 必須呼叫：關閉 consumer ExecutorService
    }

    @EzScenario
    public void should_create_[aggregate]_successfully() {
        feature.newScenario()
            .Given("a valid creation request", env -> {
                var input = Create[Aggregate]UseCase.Create[Aggregate]Input.create();
                input.[aggregate]Id = UUID.randomUUID().toString();
                input.name = "Test [Aggregate]";
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the use case is executed", env -> {
                var input = env.get("input", Create[Aggregate]UseCase.Create[Aggregate]Input.class);
                var output = useCase.execute(input);
                env.put("output", output);
            })
            .Then("the operation should succeed", env -> {
                var output = env.get("output", CqrsOutput.class);
                assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
            })
            .Execute();
    }
}
```

### 框架提供的 InMemory 類別（ezapp 2.0.0）

```java
// Repository 和 MessageBroker 由 Spring Configuration 自動配置
// 測試類別只需要透過 @Autowired 注入即可

// 可用的 InMemory 元件（正確 import 路徑 — 參考 class-index.md）：
import tw.teddysoft.ezddd.data.io.ezoutbox.InMemoryOrmDb;
import tw.teddysoft.ezddd.data.io.ezoutbox.InMemoryOrmClient;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDb;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDbClient;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryMessageProducer;
```

## ⚠️ Deprecated: 舊版手動建立模式

### 1. Import Statements (Deprecated)
**注意**: 以下模式已 deprecated，僅供參考舊版實作
```java
import tw.teddysoft.ezddd.entity.DomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageBus;
// ❌ Deprecated: BlockingMessageBus → 使用 InMemoryMessageBroker (框架內建)
import tw.teddysoft.ezddd.usecase.port.inout.messaging.impl.BlockingMessageBus;
// ❌ Deprecated: GenericInMemoryRepository → 使用 Spring DI 注入 Repository
import [rootPackage].common.adapter.out.repository.GenericInMemoryRepository;
```

### 2. TestContext Pattern (Deprecated)
**注意**: 以下模式已 deprecated，ezapp 2.0.0 使用 Spring DI 注入，不需要手動建立 TestContext

```java
static class TestContext {
    private static TestContext instance;
    // ❌ Deprecated: 不再手動建立 GenericInMemoryRepository
    private GenericInMemoryRepository<[Aggregate], [AggregateId]> [aggregate]Repository;
    private MessageBus<DomainEvent> messageBus;
    private List<DomainEvent> publishedEvents;

    private TestContext() {
        publishedEvents = new ArrayList<>();

        // ❌ Deprecated: BlockingMessageBus → 使用 InMemoryMessageBroker (框架內建)
        // 舊版: messageBus = new BlockingMessageBus();
        // ezapp 2.0.0: 由 Spring Configuration 自動配置
        messageBus = new InMemoryMessageBroker<>();

        // Register a reactor to capture domain events
        messageBus.register(event -> {
            if (event instanceof DomainEvent) {
                publishedEvents.add((DomainEvent) event);
            }
        });

        // ❌ Deprecated: 不再手動建立 GenericInMemoryRepository
        // ezapp 2.0.0: 使用 @Autowired 注入 Repository<T, ID>
        [aggregate]Repository = new GenericInMemoryRepository<>(
            messageBus,
            [aggregate] -> [AggregateId].valueOf([aggregate].getId())
        );
    }

    public static TestContext getInstance() {
        if (instance == null) {
            instance = new TestContext();
        }
        return instance;
    }

    public [CreateUseCaseName]UseCase new[CreateUseCaseName]UseCase() {
        return new [CreateUseCaseName]Service([aggregate]Repository);
    }

    public GenericInMemoryRepository<[Aggregate], [AggregateId]> [aggregate]Repository() {
        return [aggregate]Repository;
    }

    public List<DomainEvent> getPublishedEvents() {
        return new ArrayList<>(publishedEvents);
    }

    public void clearPublishedEvents() {
        publishedEvents.clear();
    }
}
```

### 3. Key Points to Remember (Deprecated)
**注意**: 以下為舊版實作重點，僅供參考

1. **MessageBus Generic Type**: Always use `MessageBus<DomainEvent>` with the generic type parameter, not raw `MessageBus`.

2. **❌ Deprecated - BlockingMessageBus**:
    - 舊版: `tw.teddysoft.ezddd.usecase.port.inout.messaging.impl.BlockingMessageBus`
    - ezapp 2.0.0: `tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker` (框架內建)

3. **Event Capture**: Register a reactor on the messageBus to capture domain events:
   ```java
   // ❌ Deprecated: 手動註冊 reactor
   // ezapp 2.0.0: 由測試框架自動處理
   messageBus.register(event -> {
       if (event instanceof DomainEvent) {
           publishedEvents.add((DomainEvent) event);
       }
   });
   ```

4. **❌ Deprecated - GenericInMemoryRepository Constructor**:
    - 舊版: 手動建立 `new GenericInMemoryRepository<>(messageBus, idExtractor)`
    - ezapp 2.0.0: 使用 `@Autowired Repository<T, ID>` 注入

5. **Repository Type**:
    - 舊版: `GenericInMemoryRepository<T extends EsAggregateRoot<String, ?>, ID>`
    - ezapp 2.0.0: `Repository<T, ID>` (由 Spring Configuration 提供實作)

### 4. Test Scenario Pattern (Deprecated)
**注意**: 以下為舊版測試模式，僅供參考

When writing test scenarios (舊版):
```java
// ❌ Deprecated: 手動從 TestContext 取得 publishedEvents
// ezapp 2.0.0: 使用 @Autowired InMemoryMessageDb 查詢事件
.And("a [aggregate] created event should be published", env -> {
    List<DomainEvent> events = getContext().getPublishedEvents();
    assertEquals(1, events.size());
    assertTrue(events.get(0) instanceof [Aggregate]Events.[Aggregate]Created);
    [Aggregate]Events.[Aggregate]Created event = ([Aggregate]Events.[Aggregate]Created) events.get(0);
    var input = env.get("input", Create[Aggregate]Input.class);
    assertEquals(input.getId(), event.[aggregate]Id());
    // Assert other event properties
})
```

**ezapp 2.0.0 推薦做法（使用 NotifyFakeHandleAllEventsService）**:
```java
// 事件收集器類別
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

> ⛔ **以下為已棄用的 OLD 架構**。請勿複製此段程式碼。
> 手動注入 relay 並呼叫 `executorService.execute(relay)` 會導致 Double Relay（Failure #5）。
> 新專案請使用 `references/templates/base-test-classes.md` 的 `BaseUseCaseTest`，
> relay 由 `VolatileRelayConfig` / `CatchupRelayConfig` 管理。

**測試中使用（⛔ DEPRECATED — 僅供歷史參考）**:
```java
@Autowired private InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker;
@Autowired private EzesVolatileRelay<DomainEventData> relay;  // ⛔ 不要注入 relay！

private NotifyFakeHandleAllEventsService notifyFakeHandleAllEventsService;
private InternalInMemoryMessageConsumer notifyHandleAllEventsConsumer;
private InMemoryConsumer<DomainEventData> inMemoryConsumer;
private ExecutorService executorService;

@BeforeEach
public void setUp() {
    notifyFakeHandleAllEventsService = new NotifyFakeHandleAllEventsService();
    inMemoryConsumer = new InMemoryConsumer<>(inMemoryMessageBroker);
    notifyHandleAllEventsConsumer = new InternalInMemoryMessageConsumer(notifyFakeHandleAllEventsService, inMemoryConsumer);
    executorService = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
    executorService.submit(notifyHandleAllEventsConsumer);
    executorService.execute(relay);
    waitForVolatileRelayToStart();
}

@Test
void testEventPublished() {
    // Execute use case
    var input = new Create[Aggregate]UseCase.Create[Aggregate]Input();
    input.[aggregate]Id = "[aggregate]-1";
    input.name = "Test";
    useCase.execute(input);

    // Verify event published
    await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
        assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize()).isEqualTo(1);
        assertThat(notifyFakeHandleAllEventsService.handledEventTimes([Aggregate]Events.[Aggregate]Created.class)).isEqualTo(1);
    });

    [Aggregate]Events.[Aggregate]Created event = ([Aggregate]Events.[Aggregate]Created) notifyFakeHandleAllEventsService.getLastHandledEvent();
    assertThat(event.[aggregate]Id().value()).isEqualTo("[aggregate]-1");
}

@AfterEach
public void tearDown() {
    if (executorService != null) {
        executorService.shutdownNow();
        try {
            executorService.awaitTermination(1, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}

private static void waitForVolatileRelayToStart() {
    try {
        Thread.sleep(50);
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    }
}
```

### 5. Repository Behavior (Deprecated)
**注意**: 以下為舊版 GenericInMemoryRepository 行為說明，僅供參考

The GenericInMemoryRepository (舊版) will:
- Call `messageBus.post()` for each domain event when `save()` or `delete()` is called
- Clear domain events from the aggregate after posting them
- Store aggregates in memory using a HashSet

**ezapp 2.0.0**: Repository 實作由框架提供，測試只需透過 `@Autowired` 注入

## Example Usage

### ezapp 2.0.0 範例：建立 CreateWorkflow UseCase 測試

> **注意**: 此範例遵循 usecase-test.md 的完整規則。
> 關鍵要素：`setUpEventCapture()`/`tearDownEventCapture()`、`@EzScenario public void`、`create()` factory。
> `@DirtiesContext` 已從 BaseUseCaseTest 繼承，不需重複。`@TestMethodOrder` 已移除（Rule 13）。

```java
import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

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
// @DirtiesContext inherited from BaseUseCaseTest — no need to repeat
// @TestMethodOrder removed (Rule 13) — @DirtiesContext ensures test isolation
public class CreateWorkflowUseCaseTest extends BaseUseCaseTest {

    @Autowired
    private CreateWorkflowUseCase useCase;

    @Autowired
    private Repository<Workflow, WorkflowId> repository;

    private Feature feature;

    @BeforeEach
    public void setUp() {
        setUpEventCapture();
        DateProvider.useSystemTime();
        feature = Feature.New("CreateWorkflow", "Create a new workflow");
    }

    @AfterEach
    public void tearDown() {
        tearDownEventCapture();
    }

    @EzScenario
    public void should_create_workflow_successfully() {
        feature.newScenario()
            .Given("a valid workflow creation request", env -> {
                var input = CreateWorkflowUseCase.CreateWorkflowInput.create();
                input.workflowId = UUID.randomUUID().toString();
                input.name = "Test Workflow";
                input.userId = "user-1";
                env.put("input", input);
            })
            .When("the create workflow use case is executed", env -> {
                var input = env.get("input", CreateWorkflowUseCase.CreateWorkflowInput.class);
                var output = useCase.execute(input);
                env.put("output", output);
            })
            .Then("the operation should succeed", env -> {
                var output = env.get("output", CqrsOutput.class);
                assertThat(output.getExitCode()).isEqualTo(ExitCode.SUCCESS);
            })
            .And("the workflow should be persisted", env -> {
                var input = env.get("input", CreateWorkflowUseCase.CreateWorkflowInput.class);
                var saved = repository.findById(WorkflowId.valueOf(input.workflowId));
                assertThat(saved).isPresent();
            })
            .And("the WorkflowCreated event should be published", env -> {
                await().atMost(10, TimeUnit.SECONDS).untilAsserted(() -> {
                    assertThat(notifyFakeHandleAllEventsService.getHandledEventsSize())
                        .isGreaterThanOrEqualTo(1);
                });
            })
            .Execute();
    }
}
```

### 舊版範例（Deprecated）

When asked to create a test for "CreateWorkflow" use case, apply this pattern:
- Replace `[Aggregate]` with `Workflow`
- Replace `[AggregateId]` with `WorkflowId`
- Replace `[aggregate]` with `workflow`
- Replace `[CreateUseCaseName]` with `CreateWorkflow`

This ensures consistent test structure and proper integration with the ezddd framework's event-driven architecture.

---

## Migration Guide: 舊版 → ezapp 2.0.0

### 主要變更

| 項目 | 舊版 | ezapp 2.0.0 |
|-----|-----|------------|
| Repository | 手動建立 `GenericInMemoryRepository` | `@Autowired Repository<T, ID>` |
| MessageBus | 手動建立 `BlockingMessageBus` | 框架提供 `InMemoryMessageBroker` |
| MessageProducer | 手動建立 `MyInMemoryMessageProducer` | 框架提供 `InMemoryMessageProducer` |
| 測試資料清理 | 手動管理 TestContext | `@Autowired InMemoryOrmDb` + `clear()` |
| Profile 控制 | `@ActiveProfiles` | TestSuite 控制（不在測試類別指定） |

### 移除的類別（不再需要）

以下類別在 ezapp 2.0.0 由框架提供，專案不需要自行實作：
- ❌ `GenericInMemoryRepository` - 使用 `@Autowired Repository<T, ID>`
- ❌ `MyInMemoryMessageBroker` - 使用框架的 `InMemoryMessageBroker`
- ❌ `MyInMemoryMessageProducer` - 使用框架的 `InMemoryMessageProducer`

### 框架提供的 InMemory 元件

```java
// Data persistence (package: ezoutbox)
tw.teddysoft.ezddd.data.io.ezoutbox.InMemoryOrmDb<T>
tw.teddysoft.ezddd.data.io.ezoutbox.InMemoryOrmClient

// Message persistence (package: ezes.store)
tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDb
tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDbClient

// Message broker
tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker<T>
tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryMessageProducer<T>
```