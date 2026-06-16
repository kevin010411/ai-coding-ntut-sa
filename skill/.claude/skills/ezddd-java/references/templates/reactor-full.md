# AI Prompt for Reactor Generation

## Context
When generating reactor for performing eventual consistency in this ai-scrum project, follow the established patterns for Clean Architecture, DDD, CQRS, and Event Sourcing with the ezddd framework.

## Important: Reactor Interface Definition (ADR-018)
- **Must extend** `Reactor<DomainEventData>`, NOT `Reactor<DomainEvent>` or just `Reactor`
- **Method signature**: `execute(DomainEventData message)`
- **Reference**: `.dev/specs/pbi/usecase/reactor/register-reactor-for-in-memory-repository-example.java`

## File Structure Pattern

For a reactor named "When[Event][Reaction]Reactor", generate the following files:

### 1. Reactor Interface - `When[Event][Reaction]Reactor.java`
Location: `src/main/java/tw/teddysoft/aiscrum/[aggregate]/usecase/reactor/When[Event][Reaction]Reactor.java`

```java
package tw.teddysoft.aiscrum.[aggregate].usecase.reactor;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

public interface When[Event][Reaction]Reactor extends Reactor<DomainEventData> {
}
```
### 2. Service Implementation - `[Reaction]When[Event]Service.java`
Location: `src/main/java/tw/teddysoft/aiscrum/[aggregate]/usecase/service/reactor/[Reaction]When[Event]Service.java`

```java
package tw.teddysoft.aiscrum.[aggregate].usecase.service.reactor;

import tw.teddysoft.aiscrum.[aggregate].usecase.reactor.When[Event][Reaction]Reactor;
import tw.teddysoft.aiscrum.[aggregate].usecase.port.out.inquiry.Find[Entity]By[Criteria]Inquiry;
import tw.teddysoft.aiscrum.[aggregate].entity.[Aggregate];
import tw.teddysoft.aiscrum.[aggregate].entity.[Aggregate]Id;
import tw.teddysoft.aiscrum.[aggregate].entity.[Aggregate]Events;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import static tw.teddysoft.ucontract.Contract.requireNotNull;

import java.util.List;

public class [Reaction]When[Event]Service implements When[Event][Reaction]Reactor {

    private final Find[Entity]By[Criteria]Inquiry inquiry;
    private final Repository<[Aggregate], [Aggregate]Id> repository;

    public [Reaction]When[Event]Service(
            Find[Entity]By[Criteria]Inquiry inquiry,
            Repository<[Aggregate], [Aggregate]Id> repository) {
        Objects.requireNonNull(inquiry);
        Objects.requireNonNull(repository);
        this.inquiry = inquiry;
        this.repository = repository;
    }

    @Override
    public void execute(DomainEventData message) {
        if (message == null) {
            return;
        }

        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

        if (domainEvent instanceof [Source]Events.[Event] event) {
            when[Event](event);
        }
        // Silently ignore other event types
    }

    private void when[Event]([Source]Events.[Event] event) {
        // 1. Query affected entities
        List<[Aggregate]Id> ids = inquiry.findBy[Criteria](event.[criteria]());

        // 2. Process each entity
        for ([Aggregate]Id id : ids) {
            var entityOpt = repository.findById(id);
            if (entityOpt.isPresent()) {
                [Aggregate] entity = entityOpt.get();
                // 3. Apply business logic with idempotency check
                entity.[action](event.userId());
                repository.save(entity);
            }
        }
    }
}
```

### 3. Test Case - `[Reaction]When[Event]ServiceTest.java`
Location: `src/test/java/tw/teddysoft/aiscrum/[aggregate]/usecase/service/reactor/[Reaction]When[Event]ServiceTest.java`

Use the test generation prompt at `codegen/test/test-case-generation-prompt.md`

## Important Notes

1. **Package Structure**: Follow package by feature then by layer
   - Entity layer: `[aggregate].entity`
   - Use case layer: `[aggregate].usecase.port.in.command.[action]`
   - Service layer: `[aggregate].usecase.service`

2. **Interface Mappings**:
   - ValueObject: `tw.teddysoft.ezddd.entity.ValueObject` (no generic parameter)
   - Use case: `tw.teddysoft.ezddd.cqrs.usecase.command.Command<Input, Output>`
   - Input: `tw.teddysoft.ezddd.usecase.port.in.interactor.Input`
   - Repository: `tw.teddysoft.ezddd.usecase.port.out.repository.Repository<T, ID>`

3. **Event Sourcing**:
   - Aggregate extends `EsAggregateRoot<[Aggregate]Id, [Aggregate]Events>`
   - Events implement `InternalDomainEvent`
   - Use `apply()` method to generate events
   - Implement `when()` method to handle state changes

4. **Contract Programming**:
   - Use `requireNotNull()` for preconditions
   - Use `ensure()` for postconditions
   - Use `invariant()` in `ensureInvariant()` method
   - Use `require()` and `reject()` for business rules

5. **Common Patterns**:
   - Use Java records for Value Objects
   - Use sealed interfaces for domain events
   - Use Auto-Registration pattern (`static mapper()` method, ADR-047) for event type registration
   - Use DateProvider.now() for timestamps
   - Generate UUID for event IDs

## Placeholder Replacements

When using this template:
- Replace `[Aggregate]` with the aggregate name (e.g., `Board`, `Workflow`)
- Replace `[aggregate]` with lowercase aggregate name (e.g., `board`, `workflow`)
- Replace `[AGGREGATE]` with uppercase aggregate name (e.g., `BOARD`, `WORKFLOW`)
- Add additional fields based on the use case specification

## 4. ReactorConfig - `{TargetAggregate}ReactorConfig.java`
Location: `src/main/java/{rootPackage}/{targetAggregate}/io/springboot/config/{TargetAggregate}ReactorConfig.java`

> **重要**：ReactorConfig 是 aggregate-specific（不是 shared），每個目標 aggregate 有自己的 ReactorConfig。
> 完整模板見 `references/patterns/usecase/reactor.md` Step 6。

```java
package ${rootPackage}.${targetAggregateLowerCase}.io.springboot.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.InMemoryConsumer;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.internal.InternalInMemoryMessageConsumer;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@Configuration
@Profile({"inmemory", "test-inmemory", "outbox", "test-outbox"})
public class ${TargetAggregate}ReactorConfig {

    private ExecutorService executorService;

    @Bean
    public Reactor<DomainEventData> ${reactorBeanName}(/* dependencies */) {
        return new ${Reaction}When${Event}Service(/* dependencies */);
    }

    @Bean
    public InMemoryConsumer<DomainEventData> ${targetAggregate}InMemoryConsumer(
            InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker) {
        return new InMemoryConsumer<>(inMemoryMessageBroker);
    }

    @Bean
    public InternalInMemoryMessageConsumer ${consumerBeanName}(
            Reactor<DomainEventData> ${reactorBeanName},
            InMemoryConsumer<DomainEventData> ${targetAggregate}InMemoryConsumer) {
        return new InternalInMemoryMessageConsumer(${reactorBeanName}, ${targetAggregate}InMemoryConsumer);
    }

    @Bean
    @Order(200)
    public CommandLineRunner ${targetAggregate}ReactorRunner(
            InternalInMemoryMessageConsumer ${consumerBeanName}) {
        return args -> {
            executorService = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
            executorService.submit(${consumerBeanName});
        };
    }

    @PreDestroy
    public void shutdown() {
        if (executorService != null) {
            executorService.shutdownNow();
            try {
                executorService.awaitTermination(2, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
```

## Testing

Always create a corresponding test using the patterns from `references/patterns/testing/usecase-test.md`:
- Use Spring DI (`@Autowired`) for repository injection
- Use `@DirtiesContext(classMode = AFTER_EACH_TEST_METHOD)` for test isolation
- Use ezSpec BDD pattern (Feature.New → newScenario → Given/When/Then → Execute)
- Verify reactor handles events correctly