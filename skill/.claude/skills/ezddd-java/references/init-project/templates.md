# Project Initialization Templates

Complete code templates for all generated files.

**Placeholder Variables:**
- `${rootPackage}` - Root package (e.g., `tw.teddysoft.aiscrum`)
- `${AppName}` - Application name in PascalCase (e.g., `AiScrum`)
- `${projectName}` - Project name (e.g., `ai-scrum`)
- `${testDbPort}` - Test database port
- `${prodDbPort}` - Production database port
- `${dbName}` - Database name
- `${dbPassword}` - Database password

---

## Phase 1: Main Application

### ${AppName}App.java

**Location:** `${mainJavaPath}/${AppName}App.java`

```java
package ${rootPackage};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main application entry point.
 * Location: Root package (required by Spring Boot component scanning)
 */
@SpringBootApplication
public class ${AppName}App {

    public static void main(String[] args) {
        SpringApplication.run(${AppName}App.class, args);
    }
}
```

---

## Phase 2: Shared Infrastructure

### DateProvider.java

**Location:** `${mainJavaPath}/common/entity/DateProvider.java`

```java
package ${rootPackage}.common.entity;

import java.time.Instant;

/**
 * Unified time provider for domain events and auditing.
 * Supports fixed time for testing.
 */
public class DateProvider {

    private static Instant fixedInstant = null;

    public static Instant now() {
        if (fixedInstant != null) {
            return fixedInstant;
        }
        return Instant.now();
    }

    public static void useFixedInstant(Instant instant) {
        fixedInstant = instant;
    }

    public static void useSystemTime() {
        fixedInstant = null;
    }
}
```

### DomainEventMapperConfig.java (ADR-047)

**Location:** `${mainJavaPath}/common/io/springboot/config/DomainEventMapperConfig.java`

```java
package ${rootPackage}.common.io.springboot.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.core.type.classreading.CachingMetadataReaderFactory;
import org.springframework.core.type.classreading.MetadataReader;
import tw.teddysoft.ezddd.data.io.ezes.store.MessageDataMapper;
import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper;

import java.lang.reflect.Method;
import java.lang.reflect.Modifier;

/**
 * Auto-registration of Domain Event TypeMappers using Spring classpath scanning.
 *
 * Uses CachingMetadataReaderFactory for reliable class discovery (no URL path parsing).
 * Scans for interfaces extending InternalDomainEvent with a static mapper() method.
 *
 * CRITICAL: This config must call MessageDataMapper.setMapper() and DomainEventMapper.setMapper()
 * to configure the global mappers. Without this, Event Sourcing will fail with:
 * "Please call setMapper to config DomainEventMapper first"
 *
 * @see ADR-047: Domain Event Auto-Registration
 */
@Configuration
public class DomainEventMapperConfig {

    private static final Logger log = LoggerFactory.getLogger(DomainEventMapperConfig.class);
    private static final String BASE_PACKAGE_PATH = "classpath*:${rootPackagePath}/**/*Events.class";

    @Bean(name = "domainEventTypeMapper")
    public DomainEventTypeMapper domainEventTypeMapper() {
        DomainEventTypeMapper globalMapper = DomainEventTypeMapper.create();

        try {
            PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
            CachingMetadataReaderFactory metadataReaderFactory = new CachingMetadataReaderFactory(resolver);
            Resource[] resources = resolver.getResources(BASE_PACKAGE_PATH);

            int registeredCount = 0;
            for (Resource resource : resources) {
                if (!resource.isReadable()) {
                    continue;
                }

                MetadataReader metadataReader = metadataReaderFactory.getMetadataReader(resource);
                String className = metadataReader.getClassMetadata().getClassName();

                // Skip inner classes (like event records containing $)
                if (className.contains("$")) {
                    continue;
                }

                try {
                    Class<?> clazz = Class.forName(className);

                    // Only process interfaces
                    if (!clazz.isInterface()) {
                        continue;
                    }

                    // Must extend InternalDomainEvent
                    if (!InternalDomainEvent.class.isAssignableFrom(clazz)) {
                        continue;
                    }

                    // Check if it has a static mapper() method
                    Method mapperMethod = clazz.getMethod("mapper");
                    if (!Modifier.isStatic(mapperMethod.getModifiers())) {
                        continue;
                    }

                    DomainEventTypeMapper mapper = (DomainEventTypeMapper) mapperMethod.invoke(null);
                    mapper.getMap().forEach(globalMapper::put);
                    registeredCount++;

                    log.debug("Registered domain events from: {}", clazz.getSimpleName());

                } catch (ClassNotFoundException e) {
                    log.warn("Could not load class: {}", className);
                } catch (NoSuchMethodException e) {
                    // No mapper() method - skip this class
                }
            }

            log.info("Registered {} domain event types from {} Events interfaces",
                    globalMapper.getMap().size(), registeredCount);

        } catch (Exception e) {
            throw new RuntimeException("Failed to scan for domain event mappers", e);
        }

        // CRITICAL: Configure global mappers for Event Sourcing to work
        MessageDataMapper.setMapper(globalMapper);
        DomainEventMapper.setMapper(globalMapper);

        return globalMapper;
    }
}
```

> **Note:** Replace `${rootPackagePath}` with the package path using `/` separators
> (e.g., `tw/teddysoft/aiscrum`). This avoids the fragile URL path parsing approach.

### SharedInfrastructureConfig.java

**Location:** `${mainJavaPath}/common/io/springboot/config/SharedInfrastructureConfig.java`

```java
package ${rootPackage}.common.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDb;
import tw.teddysoft.ezddd.data.io.ezes.store.InMemoryMessageDbClient;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Shared infrastructure configuration for InMemory profile.
 *
 * Provides: MessageDb, MessageDbClient, ExecutorService (relay threads).
 * Does NOT provide: Broker, Producer, Relay — those are in VolatileRelayConfig.
 */
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

### SharedOutboxConfig.java

**Location:** `${mainJavaPath}/common/io/springboot/config/SharedOutboxConfig.java`

```java
package ${rootPackage}.common.io.springboot.config;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.data.jpa.repository.support.JpaRepositoryFactory;
import org.springframework.data.repository.core.support.RepositoryFactorySupport;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;

/**
 * Shared Outbox configuration for PostgreSQL persistence.
 *
 * Uses EntityManager + JpaRepositoryFactory to create PgMessageDbClient proxy.
 * This avoids the need for a separate MessageStoreRepository sub-interface.
 */
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
        RepositoryFactorySupport factory = new JpaRepositoryFactory(entityManager);
        return factory.getRepository(PgMessageDbClient.class);
    }
}
```

### VolatileRelayConfig.java

**Location:** `${mainJavaPath}/common/io/springboot/config/connectionframe/VolatileRelayConfig.java`

> **⚠️ 必要配置！** 缺少此檔案會導致 InMemory profile 找不到 `InMemoryMessageBroker` bean，
> Spring Context 啟動失敗，所有測試都會失敗。

```java
package ${rootPackage}.common.io.springboot.config.connectionframe;

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
            InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker) {
        return new InMemoryProducer<>(inMemoryMessageBroker);
    }

    @Bean
    public MessageProducer<DomainEventData> messageProducer(
            InMemoryProducer<DomainEventData> inMemoryProducer) {
        return InMemoryMessageProducer.internal(inMemoryProducer);
    }

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
        relayExecutor.execute(relay);
        return relay;
    }
}
```

### CatchupRelayConfig.java

**Location:** `${mainJavaPath}/common/io/springboot/config/connectionframe/CatchupRelayConfig.java`

> **⚠️ 必要配置！** 缺少此檔案會導致 Outbox profile 啟動失敗。

```java
package ${rootPackage}.common.io.springboot.config.connectionframe;

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
            InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker) {
        return new InMemoryProducer<>(inMemoryMessageBroker);
    }

    @Bean
    public MessageProducer<DomainEventData> messageProducer(
            InMemoryProducer<DomainEventData> inMemoryProducer) {
        return InMemoryMessageProducer.internal(inMemoryProducer);
    }

    @Bean
    public EzesCatchUpRelay<DomainEventData> ezesCatchUpRelay(
            PgMessageDbClient pgMessageDbClient,
            MessageProducer<DomainEventData> messageProducer) {
        ExecutorService executor = Executors.newThreadPerTaskExecutor(Thread.ofVirtual().factory());
        Path checkpointPath = Path.of(System.getProperty("java.io.tmpdir"),
                "relay-checkpoint-" + UUID.randomUUID());
        EzesCatchUpRelay.RelayConfiguration<DomainEventData> configuration =
                EzesCatchUpRelay.RelayConfiguration.of(
                        pgMessageDbClient,
                        messageProducer,
                        checkpointPath,
                        new MessageDbToDomainEventDataConverter());
        EzesCatchUpRelay<DomainEventData> relay = new EzesCatchUpRelay<>(configuration);
        executor.execute(relay);
        return relay;
    }
}
```

---

## Phase 3: Test Infrastructure

### BaseSpringBootTest.java

**Location:** `${testJavaPath}/test/base/BaseSpringBootTest.java`

```java
package ${rootPackage}.test.base;

import org.springframework.boot.test.context.SpringBootTest;

/**
 * Base class for Use Case and Repository tests that require Spring context.
 * Contract tests do NOT extend this class (they don't need Spring).
 *
 * IMPORTANT: Do NOT add @ActiveProfiles here!
 * Profile switching is controlled by ProfileSetter in TestSuite.
 *
 * NOTE: @DirtiesContext is NOT set here — subclasses (BaseUseCaseTest) set their own
 * classMode (AFTER_EACH_TEST_METHOD) to avoid the EzesVolatileRelay Singleton Trap.
 */
@SpringBootTest
public abstract class BaseSpringBootTest {
    // Intentionally empty - provides Spring Boot test context
}
```

### NotifyFakeHandleAllEventsService.java

**Location:** `${testJavaPath}/common/NotifyFakeHandleAllEventsService.java`

> **Extracted as separate class** (not inner class of BaseUseCaseTest).
> Package: `${rootPackage}.common` (under src/test/java).

```java
package ${rootPackage}.common;

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

### BaseUseCaseTest.java

**Location:** `${testJavaPath}/test/base/BaseUseCaseTest.java`

> **必讀**：`references/examples/dual-profile-test-infrastructure.md` — 完整的 relay 生命週期、
> 7 個 failure causes 的預防對照表、InMemory/Outbox 測試時序圖。

```java
package ${rootPackage}.test.base;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import ${rootPackage}.common.NotifyFakeHandleAllEventsService;
import tw.teddysoft.ezddd.data.io.ezes.store.PgMessageDbClient;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.InMemoryConsumer;
import tw.teddysoft.ezddd.message.broker.adapter.in.consumer.internal.InternalInMemoryMessageConsumer;
import tw.teddysoft.ezddd.message.broker.io.messagebroker.InMemoryMessageBroker;
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageProducer;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * Base class for Use Case tests with event capture support.
 *
 * IMPORTANT: Relay lifecycle is managed by VolatileRelayConfig / CatchupRelayConfig.
 * Do NOT create additional relay instances here — VolatileRelayConfig already starts
 * a relay via relayExecutor.execute(relay) during Spring Context initialization.
 * Creating a second relay causes DUPLICATE EVENT DELIVERY (each event forwarded twice).
 *
 * With @DirtiesContext(AFTER_EACH_TEST_METHOD), each test gets a fresh Spring Context
 * including a new relay instance, so the Singleton Trap is avoided.
 *
 * Subclasses MUST call setUpEventCapture() in @BeforeEach
 * and tearDownEventCapture() in @AfterEach manually.
 *
 * @see EzesVolatileRelay Singleton Trap — explained in rules/testing-patterns.md §DirtiesContext
 */
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
public abstract class BaseUseCaseTest extends BaseSpringBootTest {

    @Autowired
    protected InMemoryMessageBroker<DomainEventData> inMemoryMessageBroker;

    @Autowired
    protected MessageProducer<DomainEventData> messageProducer;

    // Do NOT create relay instances here! VolatileRelayConfig manages the relay lifecycle.
    // @DirtiesContext(AFTER_EACH_TEST_METHOD) ensures a fresh relay per test.

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
     * Subclasses MUST call this in @BeforeEach.
     * NOT annotated with @BeforeEach — subclass controls invocation.
     */
    protected void setUpEventCapture() {
        System.out.println("==> Running test with profile: " + activeProfile);

        // Clean up messages table for outbox profile tests
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
        // Relay is already running via VolatileRelayConfig/CatchupRelayConfig.
        // Do NOT start another relay here — it causes duplicate event delivery!

        // For outbox profile: the CatchUpRelay (with UUID checkpoint, starting from position 0)
        // may have already relayed leftover messages from the previous test before setUpEventCapture()
        // cleaned the messages table. Wait for those stale events to be consumed, then clear them.
        if ("test-outbox".equals(activeProfile)) {
            try { Thread.sleep(200); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            notifyFakeHandleAllEventsService.clearHandledEvents();
        }
    }

    /**
     * Subclasses MUST call this in @AfterEach.
     * NOT annotated with @AfterEach — subclass controls invocation.
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
    }

    protected void clearCapturedEvents() {
        if (notifyFakeHandleAllEventsService != null) {
            notifyFakeHandleAllEventsService.clearHandledEvents();
        }
    }
}
```

### ⚠️ TestSuite — init-project 階段不產生

> **重要**：init-project 階段**不產生** TestSuite，因為尚無 aggregate、無測試類別可引用。
>
> 全專案只有兩個全域 TestSuite（`InMemoryTestSuite` + `OutboxTestSuite`），
> 在 **第一次 PF 執行時建立**，使用 `@SelectPackages` 按 aggregate package 自動掃描。
>
> **完整模板**：`references/templates/test-suites.md`
> **設計決策**：`references/examples/dual-profile-test-infrastructure.md` Section 9

---

## Phase 4: Application Properties

### application.properties

**Location:** `src/main/resources/application.properties`

```properties
spring.profiles.active=inmemory
spring.application.name=${projectName}
server.port=8080

spring.jackson.serialization.write-dates-as-timestamps=false
spring.jackson.serialization.indent-output=true

logging.level.root=INFO
logging.level.${rootPackage}=DEBUG
```

### application-inmemory.properties

**Location:** `src/main/resources/application-inmemory.properties`

```properties
# InMemory profile - exclude ALL database-related auto-configuration
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,\
  org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration,\
  org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,\
  org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration

spring.jpa.enabled=false
logging.level.${rootPackage}=DEBUG
```

### application-outbox.properties

**Location:** `src/main/resources/application-outbox.properties`

```properties
spring.datasource.url=jdbc:postgresql://localhost:${prodDbPort}/${dbName}?currentSchema=message_store
spring.datasource.username=postgres
spring.datasource.password=${dbPassword}
spring.datasource.driver-class-name=org.postgresql.Driver

spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.open-in-view=false

spring.jpa.packages-to-scan=\
  ${rootPackage},\
  tw.teddysoft.ezddd.data.io.ezes.store

messagestore.postgres.url=${spring.datasource.url}
messagestore.postgres.user=${spring.datasource.username}
messagestore.postgres.password=${spring.datasource.password}
```

### application-test-inmemory.properties

**Location:** `src/test/resources/application-test-inmemory.properties`

```properties
# InMemory profile - exclude ALL database-related auto-configuration
# Profile is activated via SPRING_PROFILES_ACTIVE environment variable (NOT in this file!)
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,\
  org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration,\
  org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,\
  org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration
```

### application-test-outbox.properties

**Location:** `src/test/resources/application-test-outbox.properties`

```properties
spring.datasource.url=jdbc:postgresql://localhost:${testDbPort}/${dbName}?currentSchema=message_store
spring.datasource.username=postgres
spring.datasource.password=${dbPassword}
spring.datasource.driver-class-name=org.postgresql.Driver

spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.default_schema=message_store

messagestore.postgres.url=${spring.datasource.url}
messagestore.postgres.user=${spring.datasource.username}
messagestore.postgres.password=${spring.datasource.password}

spring.flyway.enabled=false
```
