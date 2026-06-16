# Reactor Generation Skill

## Overview

This skill generates Reactor components for handling domain events in an event-driven architecture.
Reactors are responsible for:
- Listening to domain events from other aggregates
- Maintaining eventual consistency across bounded contexts
- Triggering side effects based on business rules

### Reactor Dependency Patterns

Reactors can be implemented using two approaches depending on the business logic scope:

1. **Direct Repository Injection** (Simpler)
   - Reactor directly injects Repository and manipulates aggregates
   - Use when reactor handles logic within the SAME aggregate boundary
   - Example: Single aggregate reactor (Category 1)

2. **UseCase Delegation** (Cross-Boundary)
   - Reactor injects and delegates to another aggregate's UseCase
   - Use when reactor CROSSES aggregate boundaries (invokes another aggregate's use case)
   - Example: RIF frames showing cross-boundary reactions

Both approaches are valid. Choose based on whether the reactor is working within one aggregate or coordinating across multiple aggregates.

---

## INPUT

| Source | Path |
|--------|------|
| RIF Frame | `JSON spec` |
| Reactor Spec | `JSON spec `reactor`` |

---

## OUTPUT

| File | Location |
|------|----------|
| Reactor Interface | `src/main/java/{rootPackage}/{targetAggregate}/usecase/reactor/{Reaction}When{Event}Reactor.java` |
| Service Implementation | `src/main/java/{rootPackage}/{targetAggregate}/usecase/service/reactor/{Reaction}When{Event}Service.java` |
| Inquiry Interface | `src/main/java/{rootPackage}/{targetAggregate}/usecase/port/out/inquiry/Find{Entity}By{Criteria}Inquiry.java` |
| JPA Inquiry | `src/main/java/{rootPackage}/{targetAggregate}/adapter/out/persistence/inquiry/JpaFind{Entity}By{Criteria}Inquiry.java` |
| ReactorConfig | `src/main/java/{rootPackage}/{targetAggregate}/io/springboot/config/{TargetAggregate}ReactorConfig.java` |

**Important:** Reactor files go in the **TARGET** aggregate's package, not the source event's aggregate!

---

## REACTOR CATEGORIES

### Category 1: Single Aggregate Reactor

**Reacts to event by modifying a single target aggregate.**

```java
// When Sprint is created, commit it to Product
public class CommitSprintWhenSprintCreatedService implements CommitSprintWhenSprintCreatedReactor {
    private final Repository<Product, ProductId> repository;

    @Override
    public void execute(DomainEventData message) {
        if (message == null) return;
        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);
        if (domainEvent instanceof SprintEvents.SprintCreated e) {
                handleSprintCreated(e);
            }
        }
    }

    private void handleSprintCreated(SprintEvents.SprintCreated event) {
        repository.findById(ProductId.valueOf(event.productId()))
            .ifPresent(product -> {
                product.commitSprint(SprintId.valueOf(event.sprintId()), event.userId());
                repository.save(product);
            });
    }
}
```

### Category 2: Multi-Entity Reactor (with Inquiry)

**Queries multiple entities and processes each one.**

```java
// When Sprint is started, start all selected PBIs
public class StartPbisWhenSprintStartedService implements StartPbisWhenSprintStartedReactor {
    private final FindPbisBySprintIdInquiry inquiry;
    private final Repository<Pbi, PbiId> repository;

    @Override
    public void execute(DomainEventData message) {
        if (message == null) return;
        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);
        if (domainEvent instanceof SprintEvents.SprintStarted e) {
                handleSprintStarted(e);
            }
        }
    }

    private void handleSprintStarted(SprintEvents.SprintStarted event) {
        List<String> pbiIds = inquiry.query(SprintId.valueOf(event.sprintId()));

        for (String pbiIdStr : pbiIds) {
            PbiId pbiId = PbiId.valueOf(pbiIdStr);
            repository.findById(pbiId).ifPresent(pbi -> {
                // Guard check for idempotency
                if (pbi.getState() == PbiState.SELECTED) {
                    pbi.start(event.userId());
                    repository.save(pbi);
                }
            });
        }
    }
}
```

### Category 3: Notification Reactor

**Sends notifications without modifying aggregates.**

```java
// When PBI is completed, notify stakeholders
public class NotifyWhenPbiCompletedService implements WhenPbiCompletedNotifyReactor {
    private final NotificationService notificationService;

    @Override
    public void execute(DomainEventData message) {
        if (message == null) return;
        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);
        if (domainEvent instanceof PbiEvents.PbiCompleted e) {
                notificationService.notifyPbiCompleted(e.pbiId(), e.userId());
            }
        }
    }
}
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Reactor Interface Type

```java
// ✅ CORRECT: Extends Reactor<DomainEventData>
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

public interface CommitSprintWhenSprintCreatedReactor extends Reactor<DomainEventData> {
}

// ❌ WRONG: Using DomainEvent
public interface WhenXxxReactor extends Reactor<DomainEvent> { }

// ❌ WRONG: Using Object
public interface WhenXxxReactor extends Reactor<Object> { }

// ❌ WRONG: Using specific event type
public interface WhenXxxReactor extends Reactor<SprintEvents.SprintCreated> { }

// ❌ WRONG: Old import path
import tw.teddysoft.ezddd.usecase.port.inout.messaging.Reactor;  // WRONG package!
```

**Rationale:** `DomainEventData` is the serialized form that comes from the message broker. `Reactor` is in `tw.teddysoft.ezddd.usecase.port.in.interactor` package.

### Rule 2: Execute Method Signature

```java
// ✅ CORRECT (Preferred): Direct DomainEventData parameter with null check
@Override
public void execute(DomainEventData message) {
    if (message == null) {
        return;
    }

    InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

    if (domainEvent instanceof SprintEvents.SprintCreated e) {
        handleSprintCreated(e);
    }
    // Silently ignore other event types
}

// ❌ WRONG: Parameter type is specific event
public void execute(SprintEvents.SprintCreated event) { }

// ❌ WRONG: Method name is handle, not execute
public void handle(DomainEventData message) { }
```

**Rationale:** The execute method receives serialized event data that needs to be deserialized via `DomainEventMapper.toDomain()`.

### Rule 3: Event Type Check with instanceof

```java
// ✅ CORRECT: Use instanceof pattern matching
if (domainEvent instanceof SprintEvents.SprintCreated e) {
    handleSprintCreated(e);
}
// Silently ignore other event types

// ❌ WRONG: No type check
SprintEvents.SprintCreated e = (SprintEvents.SprintCreated) domainEvent;  // May throw ClassCastException

// ❌ WRONG: Throwing exception for unknown events
if (!(domainEvent instanceof SprintEvents.SprintCreated)) {
    throw new IllegalArgumentException("Unknown event type");  // Reactors should silently ignore
}
```

**Rationale:** Reactors may receive events they don't care about; silently ignoring is correct.

### Rule 4: Use Inquiry for Cross-Aggregate Queries

```java
// ✅ CORRECT: Use Inquiry interface for cross-aggregate queries
public interface FindPbisBySprintIdInquiry extends Inquiry<SprintId, List<String>> {
}

// Service uses Inquiry
private final FindPbisBySprintIdInquiry inquiry;
List<String> pbiIds = inquiry.query(sprintId);

// ❌ WRONG: Repository doesn't have custom query methods
private final Repository<Pbi, PbiId> repository;
List<Pbi> pbis = repository.findBySprintId(sprintId);  // ERROR! No such method!
```

**Rationale:** Repository only has findById/save/delete. Use Inquiry for custom queries.

### Rule 5: Guard Check Pattern for Idempotency

```java
// ✅ CORRECT: Check state before executing business logic
repository.findById(pbiId).ifPresent(pbi -> {
    // Guard check - only proceed if in expected state
    if (pbi.getState() == PbiState.SELECTED) {
        pbi.start(userId);
        repository.save(pbi);
    }
    // If not in expected state, silently skip (idempotent)
});

// ❌ WRONG: No guard check - may fail or duplicate actions
repository.findById(pbiId).ifPresent(pbi -> {
    pbi.start(userId);  // May throw if already started!
    repository.save(pbi);
});
```

**Rationale:** Events may be delivered multiple times; reactors must be idempotent.

### Rule 6: Reactor Placed in TARGET Aggregate

```java
// ✅ CORRECT: Reactor for "commit sprint to product" goes in Product package
package tw.teddysoft.aiscrum.product.usecase.reactor;

public interface CommitSprintToProductWhenSprintCreatedReactor extends Reactor<DomainEventData> {
}

// ReactorConfig also in Product
package tw.teddysoft.aiscrum.product.io.springboot.config;

@Configuration
@Profile({"inmemory", "test-inmemory", "outbox", "test-outbox"})
public class ProductReactorConfig {
    @Bean
    public Reactor<DomainEventData> commitSprintToProductWhenSprintCreatedReactor(...) {
        // ...
    }
}

// ❌ WRONG: Putting in Sprint (source) package
package tw.teddysoft.aiscrum.sprint.usecase.reactor;  // WRONG!

// ❌ WRONG: Old package path with port/in/reactor/
package tw.teddysoft.aiscrum.product.usecase.port.in.reactor;  // WRONG! Use usecase/reactor/
```

**Rationale:** Reactor modifies the TARGET aggregate, so it belongs to that bounded context. Reactor interface goes in `usecase/reactor/` (not `usecase/port/in/reactor/`).

### Rule 7: No @Service or @Component

> **Shared Rule** — See `references/rules/usecase-patterns.md` § No @Service or @Component Annotation

Reactor services are registered via `@Bean` in `{TargetAggregate}ReactorConfig`.

### Rule 8: Null Check at Entry Point

```java
// ✅ CORRECT: Check for null message
@Override
public void execute(DomainEventData message) {
    if (message == null) {
        return;  // Silently ignore null
    }
    InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);
    // Process...
}

// ❌ WRONG: No null check
@Override
public void execute(DomainEventData message) {
    InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);  // NPE if null!
}
```

**Rationale:** Message brokers may deliver null payloads.

### Rule 9: DomainEventMapper for Deserialization

```java
// ✅ CORRECT: Use DomainEventMapper to convert DomainEventData to domain event
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;

InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

// ❌ WRONG: Manual deserialization
SprintEvents.SprintCreated event = objectMapper.readValue(message.getPayload(), SprintEvents.SprintCreated.class);

// ❌ WRONG: Direct casting without mapper
SprintEvents.SprintCreated event = (SprintEvents.SprintCreated) message;
```

**Rationale:** DomainEventMapper handles type registration and proper deserialization.

### Rule 10: Package Structure

> **Shared Rule** — See `references/rules/usecase-patterns.md` § Package Location Rules

Key Reactor-specific detail: Reactor interface goes in `usecase/reactor/` (NOT `port/in/reactor/`), service in `usecase/service/reactor/`.

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Input Validation

Before generating code, verify:

| Check | Command | Expected |
|-------|---------|----------|
| reactor.yaml exists | `test -f ${reactorYamlPath}` | File exists |
| Has trigger event | `grep "trigger:" ${reactorYamlPath}` | Found |
| Has target aggregate | `grep "target:" ${reactorYamlPath}` | Found |

```
IF ANY CHECK FAILS:
  Report error: "Invalid reactor.yaml: missing required field"
  STOP - do not proceed
```

### Checkpoint 2: Pre-Generation Verification

Before writing any file:

| Check | Verification |
|-------|--------------|
| Extends Reactor<DomainEventData> | Interface has correct generic type (import from `port.in.interactor`) |
| Execute signature | Method is `execute(DomainEventData message)` |
| Uses instanceof | Event type check uses instanceof pattern |
| Has guard check | State verification before business logic |
| No @Service | Service class has no Spring annotations |

```
IF ANY CHECK FAILS:
  Fix the generated code
  Re-verify before writing
```

### Checkpoint 3: Post-Generation Verification

After writing the file:

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify extends Reactor<DomainEventData>
grep "extends Reactor<DomainEventData>" ${reactorFile}
# Should return the interface declaration

# Verify no @Service annotation
grep -E "@Service|@Component" ${serviceFile}
# Should return empty

# Verify instanceof check exists
grep "instanceof.*Events\." ${serviceFile}
# Should return the event type check
```

```
IF COMPILATION FAILS:
  Analyze error
  Fix and regenerate

IF WRONG REACTOR TYPE:
  Change to Reactor<DomainEventData>
```

---

## GENERATION TEMPLATES

### Step 1: Parse Reactor Specification

Extract from reactor.yaml:
- `trigger`: Source event (e.g., "SprintEvents.SprintCreated")
- `target`: Target aggregate to modify
- `action`: Business action to perform
- `query`: Cross-aggregate query needed (optional)

### Step 2: Generate Inquiry Interface (if needed)

```java
package ${rootPackage}.${targetAggregateLowerCase}.usecase.port.out.inquiry;

import tw.teddysoft.ezddd.usecase.port.out.Inquiry;
import ${rootPackage}.${sourceAggregate}.entity.${SourceAggregate}Id;
import java.util.List;

// Inquiry<I, O> is a framework interface with query(I input) : O method
public interface Find${Entity}By${Criteria}Inquiry extends Inquiry<${CriteriaType}, List<String>> {
}
```

### Step 3: Generate JPA Inquiry Implementation

```java
package ${rootPackage}.${targetAggregateLowerCase}.adapter.out.persistence.inquiry;

import ${rootPackage}.${targetAggregateLowerCase}.usecase.port.out.inquiry.Find${Entity}By${Criteria}Inquiry;
import ${rootPackage}.${targetAggregateLowerCase}.usecase.port.out.${Entity}Data;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface JpaFind${Entity}By${Criteria}Inquiry
        extends Find${Entity}By${Criteria}Inquiry, CrudRepository<${Entity}Data, String> {

    @Override
    default List<String> query(${CriteriaType} ${criteria}) {
        return findBy${Criteria}(${criteria}.toString());
    }

    @Query("SELECT e.id FROM ${Entity}Data e WHERE e.${criteriaField} = :${criteria}")
    List<String> findBy${Criteria}(@Param("${criteria}") String ${criteriaValue});
}
```

### Step 4: Generate Reactor Interface

```java
package ${rootPackage}.${targetAggregateLowerCase}.usecase.reactor;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

public interface ${Reaction}When${Event}Reactor extends Reactor<DomainEventData> {
}
```

### Step 5: Generate Service Implementation

```java
package ${rootPackage}.${targetAggregateLowerCase}.usecase.service.reactor;

import ${rootPackage}.${targetAggregateLowerCase}.entity.${TargetAggregate};
import ${rootPackage}.${targetAggregateLowerCase}.entity.${TargetAggregate}Id;
import ${rootPackage}.${targetAggregateLowerCase}.usecase.reactor.${Reaction}When${Event}Reactor;
import ${rootPackage}.${sourceAggregate}.entity.${SourceAggregate}Events;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class ${Reaction}When${Event}Service implements ${Reaction}When${Event}Reactor {

    private final Repository<${TargetAggregate}, ${TargetAggregate}Id> repository;

    public ${Reaction}When${Event}Service(Repository<${TargetAggregate}, ${TargetAggregate}Id> repository) {
        Objects.requireNonNull(repository);
        this.repository = repository;
    }

    @Override
    public void execute(DomainEventData message) {
        if (message == null) {
            return;
        }

        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

        if (domainEvent instanceof ${SourceAggregate}Events.${Event} e) {
            handle${Event}(e);
        }
        // Silently ignore other event types
    }

    private void handle${Event}(${SourceAggregate}Events.${Event} event) {
        ${TargetAggregate}Id targetId = ${TargetAggregate}Id.valueOf(event.${targetIdField}());

        repository.findById(targetId).ifPresent(target -> {
            // Guard check for idempotency
            if (${guardCondition}) {
                target.${action}(${actionParams});
                repository.save(target);
            }
        });
    }
}
```

### Step 6: Generate ReactorConfig (with Consumer Infrastructure)

Check if `{TargetAggregate}ReactorConfig.java` exists. If not, create it with the complete template below. If exists, add new `@Bean` methods to existing config.

The ReactorConfig must include:
1. **Reactor bean** — returns `Reactor<DomainEventData>` (generic type, not specific interface)
2. **InMemoryConsumer bean** — wraps the message broker
3. **InternalInMemoryMessageConsumer bean** — connects reactor to consumer
4. **CommandLineRunner bean** — starts consumers with `@Order` annotation
5. **@PreDestroy shutdown()** — graceful shutdown of executor service

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
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@Configuration
@Profile({"inmemory", "test-inmemory", "outbox", "test-outbox"})
public class ${TargetAggregate}ReactorConfig {

    private ExecutorService executorService;

    // ========== Reactor Beans ==========

    @Bean
    public Reactor<DomainEventData> ${reactorBeanName}(
            Repository<${TargetAggregate}, ${TargetAggregate}Id> ${targetAggregateCamelCase}Repository) {
        return new ${Reaction}When${Event}Service(${targetAggregateCamelCase}Repository);
    }

    // ========== Consumer Beans ==========

    @Bean
    public InMemoryConsumer<DomainEventData> ${targetAggregateCamelCase}InMemoryConsumer(
            InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker) {
        return new InMemoryConsumer<>(inMemoryMessageBroker);
    }

    @Bean
    public InternalInMemoryMessageConsumer ${consumerBeanName}(
            Reactor<DomainEventData> ${reactorBeanName},
            InMemoryConsumer<DomainEventData> ${targetAggregateCamelCase}InMemoryConsumer) {
        return new InternalInMemoryMessageConsumer(
                ${reactorBeanName},
                ${targetAggregateCamelCase}InMemoryConsumer);
    }

    // ========== Startup ==========

    @Bean
    @Order(${orderNumber})
    public CommandLineRunner start${TargetAggregate}ReactorConsumers(
            InternalInMemoryMessageConsumer ${consumerBeanName}) {
        return args -> {
            executorService = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
            executorService.submit(${consumerBeanName});
            Thread.sleep(50);
        };
    }

    @PreDestroy
    public void shutdown() {
        if (executorService != null) {
            executorService.shutdownNow();
            try {
                if (!executorService.awaitTermination(1, TimeUnit.SECONDS)) {
                    System.out.println("${TargetAggregate} Reactor executor did not terminate in time");
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
```

---

## EXAMPLE OUTPUT

For RIF: "When Sprint Created, Commit It To Product"

**CommitSprintToProductWhenSprintCreatedReactor.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.reactor;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

public interface CommitSprintToProductWhenSprintCreatedReactor extends Reactor<DomainEventData> {
}
```

**CommitSprintToProductWhenSprintCreatedService.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.service.reactor;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.usecase.reactor.CommitSprintToProductWhenSprintCreatedReactor;
import tw.teddysoft.aiscrum.sprint.entity.SprintEvents;
import tw.teddysoft.aiscrum.sprint.entity.SprintId;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class CommitSprintToProductWhenSprintCreatedService
        implements CommitSprintToProductWhenSprintCreatedReactor {

    private final Repository<Product, ProductId> productRepository;

    public CommitSprintToProductWhenSprintCreatedService(
            Repository<Product, ProductId> productRepository) {
        Objects.requireNonNull(productRepository);
        this.productRepository = productRepository;
    }

    @Override
    public void execute(DomainEventData message) {
        if (message == null) {
            return;
        }

        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

        if (domainEvent instanceof SprintEvents.SprintCreated sprintCreated) {
            handleSprintCreated(sprintCreated);
        }
        // Silently ignore other event types
    }

    private void handleSprintCreated(SprintEvents.SprintCreated sprintCreated) {
        ProductId productId = sprintCreated.productId();
        SprintId sprintId = sprintCreated.sprintId();
        String userId = sprintCreated.creatorId();

        var productOptional = productRepository.findById(productId);
        if (productOptional.isEmpty()) {
            return;
        }

        Product product = productOptional.get();

        // Idempotency check: if sprint is already committed, skip
        if (product.isSprintCommitted(sprintId)) {
            return;
        }

        product.commitSprint(sprintId, userId);
        productRepository.save(product);
    }
}
```

**ProductReactorConfig.java:**
```java
package tw.teddysoft.aiscrum.product.io.springboot.config;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.usecase.service.reactor.CommitSprintToProductWhenSprintCreatedService;
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
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@Configuration
@Profile({"inmemory", "test-inmemory", "outbox", "test-outbox"})
public class ProductReactorConfig {

    private ExecutorService executorService;

    // ========== Reactor Beans ==========

    @Bean
    public Reactor<DomainEventData> commitSprintToProductWhenSprintCreatedReactor(
            Repository<Product, ProductId> productRepository) {
        return new CommitSprintToProductWhenSprintCreatedService(productRepository);
    }

    // ========== Consumer Beans ==========

    @Bean
    public InMemoryConsumer<DomainEventData> productInMemoryConsumer(
            InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker) {
        return new InMemoryConsumer<>(inMemoryMessageBroker);
    }

    @Bean
    public InternalInMemoryMessageConsumer commitSprintToProductConsumer(
            Reactor<DomainEventData> commitSprintToProductWhenSprintCreatedReactor,
            InMemoryConsumer<DomainEventData> productInMemoryConsumer) {
        return new InternalInMemoryMessageConsumer(
                commitSprintToProductWhenSprintCreatedReactor,
                productInMemoryConsumer);
    }

    // ========== Startup ==========

    @Bean
    @Order(2)
    public CommandLineRunner startProductReactorConsumers(
            InternalInMemoryMessageConsumer commitSprintToProductConsumer) {
        return args -> {
            executorService = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
            executorService.submit(commitSprintToProductConsumer);
            Thread.sleep(50);
        };
    }

    @PreDestroy
    public void shutdown() {
        if (executorService != null) {
            executorService.shutdownNow();
            try {
                if (!executorService.awaitTermination(1, TimeUnit.SECONDS)) {
                    System.out.println("Product Reactor executor did not terminate in time");
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

When called by `code executor`:

```
code executor
    ↓
    Step 4.2 (RIF): Invoke reactor-skill
    ├─ Input: ${problemFramePath}/machine/reactor.yaml
    ├─ Output: Reactor Interface, Service, Inquiry (if needed), ReactorConfig
    └─ Next: Step 4.3 (usecase-test-skill)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| reactor.yaml not found | Report error, STOP |
| Missing trigger event | Report error, STOP |
| Missing target aggregate | Report error, STOP |
| Compilation error | Analyze, fix, retry (max 3 attempts) |
| Wrong Reactor generic type | Change to `Reactor<DomainEventData>` |
| @Service annotation found | Remove - use @Bean in ReactorConfig |

---
