# Framework API Reference (ezapp-starter 2.0.0)

## Correct Import Paths

```java
// Core Domain
import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.entity.EsAggregateRoot;
import tw.teddysoft.ezddd.entity.ValueObject;

// CQRS
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

// Repository
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

// Contract
import static tw.teddysoft.ucontract.Contract.*;
```

## WRONG Imports (Compilation Errors)

```java
// OLD ezddd-core paths - DO NOT USE!
import tw.teddysoft.ezddd.eventsourcing.domain.InternalDomainEvent;  // WRONG!
import tw.teddysoft.ezddd.eventsourcing.aggregate.EsAggregateRoot;   // WRONG!
```

## Query UseCase (IDF) — Projection Import ⭐⭐⭐⭐⭐

> **⚠️ CRITICAL**: Projection 的 import 路徑在 ezapp-starter 2.0.0 已遷移至 `cqrs.usecase.query` 包。
> 這是最常見的編譯錯誤之一！

```java
// ✅ CORRECT: Query UseCase interface
import tw.teddysoft.ezddd.cqrs.usecase.query.Query;

// ✅ CORRECT: Projection and ProjectionInput
import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.Projection.ProjectionInput;

// ❌ WRONG: These paths DO NOT EXIST! (Old package path)
import tw.teddysoft.ezddd.usecase.port.out.repository.projection.Projection;      // COMPILATION ERROR!
import tw.teddysoft.ezddd.usecase.port.out.repository.projection.ProjectionInput;  // COMPILATION ERROR!
import tw.teddysoft.ezddd.usecase.port.out.Projection;                             // COMPILATION ERROR!
```

**Projection 定義範例**：
```java
import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.Projection.ProjectionInput;

public abstract class ProductProjection
        extends Projection<ProductProjection.ProductProjectionInput, Optional<ProductReadOnly>> {

    public static class ProductProjectionInput implements ProjectionInput {
        public final String productId;
        public ProductProjectionInput(String productId) { this.productId = productId; }
    }
}
```

## DomainEventMapper API (ADR-047) ⭐⭐⭐⭐⭐

> **⚠️ CRITICAL**: `DomainEventMapper.toDomain()` 只接受 **1 個參數**（DomainEventData）。
> ADR-047 的 auto-registration 機制讓 `DomainEventMapperConfig` 自動註冊所有 mapper，
> 不需要傳入個別 mapper。

```java
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;

// ✅ CORRECT: Global mapper, only 1 argument
InternalDomainEvent domainEvent = DomainEventMapper.toDomain(eventData);

// ✅ CORRECT: In OutboxMapper toData(), use method reference
data.setDomainEventDatas(
    aggregate.getDomainEvents().stream()
        .map(DomainEventMapper::toData)
        .collect(Collectors.toList()));

// ❌ FORBIDDEN: Passing mapper as second argument — NO SUCH OVERLOAD!
DomainEventMapper.toDomain(eventData, ProductEvents.mapper());   // COMPILATION ERROR!
DomainEventMapper.toDomain(eventData, mapper);                    // COMPILATION ERROR!
```

## Reactor Method Name ⭐⭐⭐⭐

> **⚠️ WARNING**: `Reactor<DomainEventData>` 介面的方法名稱是 `execute()`，不是 `react()`。

```java
// ✅ CORRECT: Method name is execute()
@Override
public void execute(DomainEventData message) { ... }

// ❌ WRONG: Method name is NOT react()! (does not override interface method)
@Override
public void react(DomainEventData message) { ... }    // COMPILATION ERROR!

// ❌ WRONG: Method name is NOT handle()!
@Override
public void handle(DomainEventData message) { ... }   // COMPILATION ERROR!
```

## CqrsOutput API

> **兩種等價寫法**：`.succeed()` 等同於 `.setExitCode(ExitCode.SUCCESS)`；`.fail()` 等同於 `.setExitCode(ExitCode.FAILURE)`。
> Code generation templates 中兩種風格皆可使用（參見 `patterns/usecase/command.md` Rule 8）。

```java
// CORRECT: Fluent chaining (succeed/fail return self for chaining)
CqrsOutput<?> output = CqrsOutput.create()
    .setId(id.value())
    .succeed();

CqrsOutput<?> output = CqrsOutput.create()
    .setId(input.productId())
    .setMessage(e.getMessage())
    .fail();

// CORRECT: Check success/failure with ExitCode
if (output.getExitCode() == ExitCode.SUCCESS) { ... }
if (output.getExitCode() == ExitCode.FAILURE) { ... }

// In tests:
assertEquals(ExitCode.SUCCESS, output.getExitCode());
assertEquals(ExitCode.FAILURE, output.getExitCode());

// WRONG - No such methods!
output.isSucceeded();                               // ❌ 不存在！用 getExitCode() == ExitCode.SUCCESS
output.succeed("message", id);                      // ❌ succeed() 不接受參數！
output.fail("message");                             // ❌ fail() 不接受參數！用 .setMessage("msg").fail()
new CqrsOutput(ExitCode.SUCCESS, id, message);      // ❌ 無此建構子
output.exitCode();                                  // ❌ 正確方法是 getExitCode()
output.aggregateId();                               // ❌ 正確方法是 getId()
```

## Contract API — requireNotNull() Returns void

> **⚠️ CRITICAL WARNING**: `Contract.requireNotNull()` returns `void`, NOT the validated value.
> Do NOT use it in assignment expressions!

```java
// ✅ CORRECT: Call requireNotNull() first, then assign separately
requireNotNull("ProductId", productId);
this.productId = productId;

// ✅ CORRECT: In Mapper toDomain()
requireNotNull("ProductData", data);
ProductId id = ProductId.valueOf(data.getId());

// ❌ WRONG: Using requireNotNull() as assignment — COMPILATION ERROR!
this.productId = requireNotNull("ProductId", productId);  // void cannot be converted!
ProductId id = requireNotNull("ProductId", productId);     // void cannot be converted!
```

## EsAggregateRoot API

```java
// CORRECT
apply(new MyEvent(...));

// WRONG - No such methods!
raiseEvent(event);
addDomainEvent(event);
```

## Repository API (Only 3 Methods Allowed)

```java
// CORRECT
repository.findById(id);
repository.save(aggregate);
repository.delete(aggregate);

// WRONG - No custom queries!
repository.findByName(name);  // Forbidden!
```

## Spring Service Registration

<!-- @authority: usecaseconfig_no_profile | source: patterns/infrastructure/config.md#Rule-5 -->

```java
// CORRECT - use @Bean
@Configuration
public class ProductUseCaseConfig {
    @Bean
    public CreateProductUseCase createProductUseCase(Repository<...> repository) {
        return new CreateProductService(repository);
    }
}

// WRONG - no @Service/@Component
@Service
public class CreateProductService { }
```

## Command UseCase Interface

<!-- @authority: command_input_type | source: patterns/usecase/command.md -->
<!-- @authority: cqrs_output_wildcard | source: patterns/usecase/command.md -->

```java
// CORRECT: Command interface
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface CreateProductUseCase extends Command<CreateProductUseCase.CreateProductInput, CqrsOutput<?>> {
    // ✅ Input must be class with create() factory (authority: command.md)
    class CreateProductInput implements Input {
        public String productId;
        public String name;
        public String userId;
        public String note;
        public String extension;

        public static CreateProductInput create() {
            return new CreateProductInput();
        }
    }
}

// WRONG imports and class names:
import tw.teddysoft.ezddd.usecase.port.in.interactor.CommandUseCase;  // ❌ 不存在！用 Command
import tw.teddysoft.ezddd.usecase.port.in.interactor.CqrsOutput;     // ❌ 包路徑錯！用 cqrs.usecase.CqrsOutput
record Input(...) {}                                                   // ❌ 未 implements Input！
```

## DomainEventTypeMapper API

```java
// CORRECT: 使用 MAPPING_TYPE_PREFIX 常數作為 key 前綴（authority: domain-event.md Rule 7）
String MAPPING_TYPE_PREFIX = "ProductEvents$";

static DomainEventTypeMapper mapper() {
    DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
    mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
    return mapper;
}

// WRONG: 使用 Class.getName() — 不符合專案 MAPPING_TYPE_PREFIX 慣例！
mapper.put(ProductCreated.class.getName(), ProductCreated.class);  // ❌ 用 MAPPING_TYPE_PREFIX

// WRONG: put() 不接受單一參數！
mapper.put(ProductCreated.class);  // ❌ 編譯錯誤！需要 (String, Class)
```

<!-- @authority: inmemory_ormdb_map_constructor | source: patterns/infrastructure/config.md#Rule-6 -->

## InMemoryMessageProducer API

```java
// CORRECT: 使用靜態工廠方法（無公開建構子）
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryMessageProducer;
import tw.teddysoft.ezddd.message.broker.adapter.out.producer.InMemoryProducer;

InMemoryProducer<DomainEventData> producer = new InMemoryProducer<>(broker);
MessageProducer<DomainEventData> messageProducer = InMemoryMessageProducer.internal(producer);

// WRONG: 無公開建構子！
new InMemoryMessageProducer<>(broker);  // ❌ 編譯錯誤！
```

> **Cross-ref**: `InMemoryMessageProducer` is used inside `VolatileRelayConfig` and `CatchupRelayConfig`.
> See Relay API section below for complete connection frame setup.

## Relay / Connection Frame API (FC-8, FC-12)

> **⚠️ CRITICAL**: Relay classes are in `tw.teddysoft.ezddd.data`, NOT `tw.teddysoft.ezddd.message.relay`!

```java
// ✅ CORRECT imports (RelayConfiguration is inner class, no separate import needed)
import tw.teddysoft.ezddd.data.EzesVolatileRelay;
import tw.teddysoft.ezddd.data.EzesCatchUpRelay;
import tw.teddysoft.ezddd.data.adapter.ezes.out.MessageDbToDomainEventDataConverter;

// ❌ WRONG imports — these packages DO NOT EXIST!
import tw.teddysoft.ezddd.message.relay.adapter.out.EzesVolatileRelay;   // WRONG!
import tw.teddysoft.ezddd.message.relay.adapter.out.EzesCatchUpRelay;    // WRONG!
import tw.teddysoft.ezddd.message.relay.EzesVolatileRelay;               // WRONG!
```

### EzesVolatileRelay (InMemory profile — 3 params)

```java
// ✅ CORRECT: VolatileRelay uses inner class RelayConfiguration.of() with 3 parameters
EzesVolatileRelay relay = new EzesVolatileRelay(
    EzesVolatileRelay.RelayConfiguration.of(
        messageDbClient, // InMemoryMessageDbClient (implements MessageDbClient)
        producer,       // MessageProducer<DomainEventData>
        converter       // MessageDbToDomainEventDataConverter
    )
);

// Usage: submit to ExecutorService (relay implements Runnable)
executorService.submit(relay);
```

### EzesCatchUpRelay (Outbox profile — 4 params)

```java
// ✅ CORRECT: CatchUpRelay uses inner class RelayConfiguration.of() with 4 parameters
EzesCatchUpRelay relay = new EzesCatchUpRelay(
    EzesCatchUpRelay.RelayConfiguration.of(
        messageDbClient, // PgMessageDbClient (implements MessageDbClient)
        producer,       // MessageProducer<DomainEventData>
        checkpointPath, // Path: file path for checkpoint persistence
        converter       // MessageDbToDomainEventDataConverter
    )
);

// Usage: submit to ExecutorService (relay implements Runnable)
executorService.submit(relay);
```

### VolatileRelay vs CatchUpRelay — Parameter Comparison

| Aspect | EzesVolatileRelay | EzesCatchUpRelay |
|--------|-------------------|------------------|
| **Profile** | inmemory / test-inmemory | outbox / test-outbox |
| **Import** | `tw.teddysoft.ezddd.data.EzesVolatileRelay` | `tw.teddysoft.ezddd.data.EzesCatchUpRelay` |
| **RelayConfiguration.of()** | `EzesVolatileRelay.RelayConfiguration.of(messageDbClient, producer, converter)` | `EzesCatchUpRelay.RelayConfiguration.of(messageDbClient, producer, checkpointPath, converter)` |
| **MessageDb type** | `InMemoryMessageDbClient` | `PgMessageDbClient` |
| **Checkpoint** | Not needed (volatile) | Required: file path for position tracking |

### DomainEventTypeMapper Merge Pattern (FC-9)

```java
// ✅ CORRECT: Use getMap().forEach() to merge mappers
DomainEventTypeMapper compositeMapper = DomainEventTypeMapper.create();
DomainEventTypeMapper eventMapper = ProductEvents.mapper();
eventMapper.getMap().forEach(compositeMapper::put);

// ❌ WRONG: putAll() DOES NOT EXIST on DomainEventTypeMapper!
compositeMapper.putAll(eventMapper);           // Compilation error!
compositeMapper.putAll(eventMapper.getMap());  // Compilation error!
```

## uContract Exception Classes (FC-10)

> **⚠️ CRITICAL**: `ContractViolationException` DOES NOT EXIST!
> The uContract framework uses specific exception classes for each contract type.

```java
// ✅ CORRECT: Specific exception classes
import tw.teddysoft.ucontract.PreconditionViolationException;
import tw.teddysoft.ucontract.PostconditionViolationException;
import tw.teddysoft.ucontract.ClassInvariantViolationException;

// ❌ WRONG: This class DOES NOT EXIST in uContract!
import tw.teddysoft.ucontract.ContractViolationException;  // Compilation error!
```

| Exception Class | Triggered When | Thrown By |
|-----------------|---------------|-----------|
| `PreconditionViolationException` | `require()` / `requireNotNull()` fails | Method entry check |
| `PostconditionViolationException` | `ensure()` fails | Method exit check |
| `ClassInvariantViolationException` | `invariant()` fails | Automatic at public method entry |

```java
// Test example: catching precondition violation
@Test
public void reject_null_name() {
    assertThrows(PreconditionViolationException.class, () -> {
        new Product(productId, null, userId);
    });
}

// ❌ WRONG: ContractViolationException does not exist!
assertThrows(ContractViolationException.class, () -> { ... });
```

## OrmClient / SpringJpaClient API

<!-- @authority: ormclient_extends_springjpaclient | source: patterns/infrastructure/config.md#Rule-4 -->

```java
// CORRECT: OrmClient 有兩個型別參數
import tw.teddysoft.ezddd.data.io.ezoutbox.OrmClient;       // OrmClient<T extends StoreData, ID>
import tw.teddysoft.ezddd.data.io.ezoutbox.SpringJpaClient;  // SpringJpaClient<T extends StoreData<ID>, ID>

// JPA OrmClient 應繼承 SpringJpaClient（整合 OrmClient + CrudRepository）
// updateVersion 已由 SpringJpaClient 實作，不需要覆寫
public interface ProductOrmClient extends SpringJpaClient<ProductData, String> {
}

// WRONG: 型別參數數量不對 / 分開繼承
OrmClient<ProductData>                                      // ❌ 缺少 ID 型別參數！
extends JpaRepository<T, ID>, OrmClient<T>                  // ❌ 用 SpringJpaClient 取代
```

## ezSpec BDD Testing

<!-- @authority: dirtiescontext_after_each | source: rules/testing-patterns.md -->

```java
// CORRECT - ezSpec BDD (Feature.New → newScenario → Given/When/Then → Execute)
import tw.teddysoft.ezspec.keyword.Feature;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;

@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {

    @Autowired
    CreateProductUseCase createProductUseCase;

    @EzScenario
    public void create_a_valid_product_with_required_fields_only() {  // ⚠️ 必須 public！
        Feature.New("Create Product")
                .newScenario()
                .Given("A user is authorized", env -> {
                    // setup
                })
                .When("The user creates a product", env -> {
                    CqrsOutput<?> output = createProductUseCase.execute(input);
                    assertEquals(ExitCode.SUCCESS, output.getExitCode());
                })
                .Then("Product is saved", env -> {
                    // assertions
                })
                .Execute();
    }
}

// ⚠️ CRITICAL RULES:
// 1. 測試方法必須是 public void，只加 @EzScenario（不需要 @Test，ezSpec 有自己的 test engine）
// 2. 方法名用大寫開頭：Given, When, Then, And, But, Execute（不是 given, when, then, perform）
// 3. Lambda 型別是 Consumer<ScenarioEnvironment>（不是 Runnable）
// 4. EzScenario 是 @Annotation（不是有靜態方法的類別）

// ✅ CORRECT import:
// import tw.teddysoft.ezspec.extension.junit5.EzScenario;

// WRONG patterns:
import tw.teddysoft.ezspec.EzScenario;                                // ❌ 不存在的路徑
import tw.teddysoft.ezspec.testannotation.EzScenario;                 // ❌ 不存在的路徑
EzScenario.feature("name").scenario("name").given(...).perform();     // ❌ 完全不存在的 API
feature("name").scenario("name").given(() -> {}).when(() -> {});       // ❌ 靜態方法不存在
void should_test_something() { Feature.New("...") }                   // ❌ 必須 public！
```

## Key Framework Classes

| Class | Purpose | Package |
|-------|---------|---------|
| `EsAggregateRoot<ID, Events>` | Event Sourced Aggregate base | `tw.teddysoft.ezddd.entity` |
| `InternalDomainEvent` | Domain Event marker | `tw.teddysoft.ezddd.entity` |
| `DomainEventTypeMapper` | Event type registry | `tw.teddysoft.ezddd.entity` |
| `ValueObject` | Value Object marker | `tw.teddysoft.ezddd.entity` |
| `CqrsOutput<T>` | Command result | `tw.teddysoft.ezddd.cqrs.usecase` |
| `Command<I, O>` | Command use case interface | `tw.teddysoft.ezddd.cqrs.usecase.command` |
| `Input` | Use case input marker | `tw.teddysoft.ezddd.usecase.port.in.interactor` |
| `ExitCode` | SUCCESS / FAILURE enum | `tw.teddysoft.ezddd.usecase.port.in.interactor` |
| `Repository<T, ID>` | Repository interface | `tw.teddysoft.ezddd.usecase.port.out.repository` |
| `OrmClient<T, ID>` | ORM client interface | `tw.teddysoft.ezddd.data.io.ezoutbox` |
| `SpringJpaClient<T, ID>` | JPA OrmClient (extends OrmClient + CrudRepository) | `tw.teddysoft.ezddd.data.io.ezoutbox` |
| `InMemoryMessageProducer` | Message producer (use `.internal()` factory) | `tw.teddysoft.ezddd.message.broker.adapter.out.producer` |
| `InMemoryProducer<Message>` | Bridge class for InMemoryMessageProducer | `tw.teddysoft.ezddd.message.broker.adapter.out.producer` |
| `Feature` | BDD Feature class | `tw.teddysoft.ezspec.keyword` |
| `ScenarioEnvironment` | BDD step context (put/get data) | `tw.teddysoft.ezspec.keyword` |
| `Contract.*` | DBC utilities | `tw.teddysoft.ucontract` |
| `PreconditionViolationException` | Thrown when `require()` fails | `tw.teddysoft.ucontract` |
| `PostconditionViolationException` | Thrown when `ensure()` fails | `tw.teddysoft.ucontract` |
| `ClassInvariantViolationException` | Thrown when `invariant()` fails | `tw.teddysoft.ucontract` |
| `EzesVolatileRelay` | InMemory relay (Runnable) | `tw.teddysoft.ezddd.data` |
| `EzesCatchUpRelay` | Outbox relay (Runnable) | `tw.teddysoft.ezddd.data` |
| `EzesVolatileRelay.RelayConfiguration` | Volatile relay config (inner class) | `tw.teddysoft.ezddd.data.EzesVolatileRelay` |
| `EzesCatchUpRelay.RelayConfiguration` | CatchUp relay config (inner class) | `tw.teddysoft.ezddd.data.EzesCatchUpRelay` |
| `MessageDbToDomainEventDataConverter` | Event converter for relays | `tw.teddysoft.ezddd.data.adapter.ezes.out` |
| `DateProvider` | Testable time source (returns `Instant` only) | Local utility |

## DateProvider API ⭐⭐

> **⚠️ CRITICAL**: `DateProvider.now()` 回傳 `Instant`，**沒有** `nowLocalDateTime()` 方法。
> 需要 `LocalDateTime` 時必須明確轉換。

```java
// ✅ CORRECT: DateProvider.now() returns Instant
Instant now = DateProvider.now();

// ✅ CORRECT: Convert to LocalDateTime explicitly when needed
LocalDateTime currentTime = LocalDateTime.ofInstant(DateProvider.now(), ZoneId.systemDefault());

// ✅ CORRECT: Use in tests for time control
DateProvider.useSystemTime();                    // Reset to real time
DateProvider.useFixedInstant(Instant.parse("...")); // Fix time for testing

// ❌ WRONG: Method does not exist!
LocalDateTime now = DateProvider.nowLocalDateTime();  // Compilation error!
LocalDate today = DateProvider.nowLocalDate();        // Compilation error!
```

**Why Instant-only?** `DateProvider` 是專案統一的時間來源，使用 `Instant`
確保所有 domain event 的 `occurredOn` 一致。`LocalDateTime` 的時區由呼叫者決定。
