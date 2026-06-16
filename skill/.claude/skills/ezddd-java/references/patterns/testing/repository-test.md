# Repository Test Pattern

## Overview

Repository Test 驗證 Outbox Pattern 的 Infrastructure 層正確性：
- Mapper (toData/toDomain) 轉換正確
- Persistent Object (Data class) 所有欄位映射正確
- Spring Bean 配置正確注入
- JPA Entity 與資料庫 schema 一致

## Trigger Conditions

```yaml
# 檢查 project-config.json
trigger_conditions:
  any_of:
    - architecture.defaultPattern == "outbox"
    - architecture.commandDefaults.dualProfileSupport == true
    - architecture.commandDefaults.generateOutboxPattern == true
```

**當以上任一條件成立時，必須產生 Repository Test。**

## File Location

```
src/test/java/{rootPackage}/{aggregate}/adapter/out/repository/{Aggregate}RepositoryTest.java
```

## Test Structure

```java
package {rootPackage}.{aggregate}.adapter.out.repository;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.transaction.annotation.Transactional;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;
import tw.teddysoft.ezspec.EzFeature;
import tw.teddysoft.ezspec.EzFeatureReport;
import tw.teddysoft.ezspec.extension.junit5.EzScenario;
import tw.teddysoft.ezspec.keyword.Feature;
import tw.teddysoft.ezspec.visitor.PlainTextReport;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {Aggregate} Outbox Repository Integration Test
 *
 * 驗證 OutboxRepository 實作與資料庫的整合正確性。
 *
 * 測試涵蓋範圍：
 * 1. 資料持久化 - 驗證所有欄位正確儲存到資料庫
 * 2. 資料讀取 - 驗證從資料庫讀取的完整性
 * 3. 軟刪除 - 驗證 isDeleted 標記而非實體刪除
 * 4. 版本控制 - 驗證樂觀鎖機制
 *
 * 執行方式：SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest={Aggregate}RepositoryTest
 */
// ⚠️ 不要使用 @ActiveProfiles！Profile 由 TestSuite 的 ProfileSetter 或環境變數控制
// 詳見：ADR-021 Profile-Based Testing Architecture
@SpringBootTest(classes = {App}.class)
@Transactional
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
@EzFeature
@EzFeatureReport
public class {Aggregate}RepositoryTest {

    static String FEATURE_NAME = "{Aggregate} Outbox Repository";
    static Feature feature;
    static String PERSIST_RULE = "{Aggregate} data should be correctly persisted to database";
    static String RETRIEVE_RULE = "{Aggregate} data should be completely retrieved from database";
    static String SOFT_DELETE_RULE = "{Aggregate} should be soft deleted with isDeleted flag";
    static String VERSION_CONTROL_RULE = "Optimistic locking should work with version control";

    private final Repository<{Aggregate}, {Aggregate}Id> repository;
    private final EntityManager entityManager;

    @Autowired
    public {Aggregate}RepositoryTest(
            Repository<{Aggregate}, {Aggregate}Id> repository,
            EntityManager entityManager) {
        this.repository = repository;
        this.entityManager = entityManager;
    }

    @BeforeAll
    static void beforeAll() {
        feature = Feature.New(FEATURE_NAME);
        feature.initialize();
        feature.NewRule(PERSIST_RULE);
        feature.NewRule(RETRIEVE_RULE);
        feature.NewRule(SOFT_DELETE_RULE);
        feature.NewRule(VERSION_CONTROL_RULE);
    }

    @BeforeEach
    void setUp() {
        // ADR-047: DomainEventMapperConfig 使用 Spring ClassPath Scanning 自動處理
    }

    @AfterAll
    static void afterAll() {
        PlainTextReport report = new PlainTextReport();
        feature.accept(report);
        System.out.println(report.getOutput());
    }

    // Test methods below...
}
```

## Required Test Cases

### 1. Persist Test (MANDATORY)

**Purpose**: 驗證 Aggregate 的所有欄位都正確儲存到資料庫

```java
@EzScenario
public void should_persist_{aggregate}_to_database_with_all_fields() {
    feature.newScenario()
        .withRule(PERSIST_RULE)
        .Given("a {Aggregate} aggregate with complete data", env -> {
            // 建立完整的 Aggregate 實例
            {Aggregate}Id id = {Aggregate}Id.valueOf("test-{aggregate}-" + System.currentTimeMillis());
            {Aggregate} aggregate = new {Aggregate}(id, /* 其他必要參數 */);

            // 設定所有可選欄位（如果有的話）
            // aggregate.setXxx(...);

            env.put("aggregate", aggregate);
            env.put("aggregateId", id);
        })
        .When("save the {aggregate} using OutboxRepository", env -> {
            {Aggregate} aggregate = env.get("aggregate", {Aggregate}.class);
            repository.save(aggregate);
            entityManager.flush();
            env.put("savedVersion", aggregate.getVersion());
        })
        .Then("the {aggregate} should be persisted in database", env -> {
            {Aggregate}Id id = env.get("aggregateId", {Aggregate}Id.class);

            // 驗證可以從 Repository 讀取
            Optional<{Aggregate}> saved = repository.findById(id);
            assertThat(saved).isPresent();

            // 直接查詢資料庫驗證所有欄位
            Query query = entityManager.createNativeQuery(
                "SELECT {column1}, {column2}, version, is_deleted " +
                "FROM {schema}.{table_name} WHERE id = ?1"
            );
            query.setParameter(1, id.value());

            Object[] result = (Object[]) query.getSingleResult();
            assertThat(result).isNotNull();
            // 驗證每個欄位...
            assertThat(result[result.length - 2]).isNotNull();  // version
            assertThat(result[result.length - 1]).isEqualTo(false);  // is_deleted
        }).Execute();
}
```

### 2. Retrieve Test (MANDATORY)

**Purpose**: 驗證從資料庫讀取的資料完整性

```java
@EzScenario
public void should_retrieve_{aggregate}_with_complete_data() {
    feature.newScenario()
        .withRule(RETRIEVE_RULE)
        .Given("a {aggregate} exists in database", env -> {
            {Aggregate}Id id = {Aggregate}Id.valueOf("test-{aggregate}-" + System.currentTimeMillis());
            {Aggregate} aggregate = new {Aggregate}(id, /* params */);

            repository.save(aggregate);
            entityManager.flush();
            entityManager.clear();  // 清除快取，強制從資料庫讀取

            env.put("aggregateId", id);
        })
        .When("retrieve the {aggregate} from repository", env -> {
            {Aggregate}Id id = env.get("aggregateId", {Aggregate}Id.class);
            Optional<{Aggregate}> result = repository.findById(id);
            env.put("retrieved", result.orElse(null));
        })
        .Then("all {aggregate} data should be completely loaded", env -> {
            {Aggregate} retrieved = env.get("retrieved", {Aggregate}.class);

            assertThat(retrieved).isNotNull();
            // 驗證所有欄位都正確載入
            // assertThat(retrieved.getXxx()).isEqualTo(...);
        }).Execute();
}
```

### 3. Soft Delete Test (MANDATORY)

**Purpose**: 驗證軟刪除功能（標記 isDeleted 而非實體刪除）

```java
@EzScenario
public void should_soft_delete_{aggregate}() {
    feature.newScenario()
        .withRule(SOFT_DELETE_RULE)
        .Given("a {aggregate} exists in database", env -> {
            {Aggregate}Id id = {Aggregate}Id.valueOf("test-{aggregate}-delete-" + System.currentTimeMillis());
            {Aggregate} aggregate = new {Aggregate}(id, /* params */);

            repository.save(aggregate);
            entityManager.flush();

            env.put("aggregateId", id);
            env.put("aggregate", aggregate);
        })
        .When("soft delete the {aggregate} using repository", env -> {
            {Aggregate} aggregate = env.get("aggregate", {Aggregate}.class);
            aggregate.markAsDelete("test-user");  // 或相應的刪除方法
            repository.save(aggregate);  // 使用 save 而不是 delete 來執行軟刪除
            entityManager.flush();
        })
        .Then("{aggregate} should be marked as deleted but remain in database", env -> {
            {Aggregate}Id id = env.get("aggregateId", {Aggregate}Id.class);

            // 驗證資料仍在資料庫中
            Query countQuery = entityManager.createNativeQuery(
                "SELECT COUNT(*) FROM {schema}.{table_name} WHERE id = ?1"
            );
            countQuery.setParameter(1, id.value());

            Long count = (Long) countQuery.getSingleResult();
            assertThat(count).isEqualTo(1L);

            // 驗證 isDeleted 標記
            Query deleteQuery = entityManager.createNativeQuery(
                "SELECT is_deleted FROM {schema}.{table_name} WHERE id = ?1"
            );
            deleteQuery.setParameter(1, id.value());

            Boolean isDeleted = (Boolean) deleteQuery.getSingleResult();
            assertThat(isDeleted).isTrue();
        }).Execute();
}
```

### 4. Version Control Test (MANDATORY)

**Purpose**: 驗證樂觀鎖機制

```java
@EzScenario
public void should_handle_version_control_for_optimistic_locking() {
    feature.newScenario()
        .withRule(VERSION_CONTROL_RULE)
        .Given("a {aggregate} exists in database", env -> {
            {Aggregate}Id id = {Aggregate}Id.valueOf("test-{aggregate}-version-" + System.currentTimeMillis());
            {Aggregate} aggregate = new {Aggregate}(id, /* params */);

            repository.save(aggregate);
            entityManager.flush();

            env.put("aggregateId", id);
            env.put("aggregate", aggregate);
            env.put("initialVersion", aggregate.getVersion());
        })
        .When("update and save the {aggregate}", env -> {
            {Aggregate} aggregate = env.get("aggregate", {Aggregate}.class);

            // 執行某個會改變狀態的操作
            // aggregate.doSomething(...);

            repository.save(aggregate);
            entityManager.flush();

            env.put("updatedVersion", aggregate.getVersion());
        })
        .Then("version number should be incremented", env -> {
            Long initialVersion = env.get("initialVersion", Long.class);
            Long updatedVersion = env.get("updatedVersion", Long.class);
            {Aggregate}Id id = env.get("aggregateId", {Aggregate}Id.class);

            // 驗證版本號增加
            assertThat(updatedVersion).isGreaterThan(initialVersion);

            // 驗證資料庫中的版本號
            Query query = entityManager.createNativeQuery(
                "SELECT version FROM {schema}.{table_name} WHERE id = ?1"
            );
            query.setParameter(1, id.value());

            Long dbVersion = (Long) query.getSingleResult();
            assertThat(dbVersion).isEqualTo(updatedVersion);
        }).Execute();
}
```

## Key Rules

### 1. Profile Management

```
⚠️ 不要使用 @ActiveProfiles！
Profile 由 TestSuite 的 ProfileSetter 或環境變數控制 (ADR-021)

執行方式：
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest={Aggregate}RepositoryTest
```

### 2. Test Isolation

```java
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
```

確保每個測試有乾淨的 Spring Context，避免 EzesVolatileRelay singleton trap。

### 3. Transactional Rollback

```java
@Transactional
```

每個測試後自動 rollback，保持資料庫乾淨。

### 4. Database Verification

```java
// 使用 entityManager.flush() 確保資料寫入資料庫
entityManager.flush();

// 使用 entityManager.clear() 清除快取，強制從資料庫讀取
entityManager.clear();

// 使用 Native Query 直接驗證資料庫內容
Query query = entityManager.createNativeQuery("SELECT ... FROM ...");
```

## Placeholder Reference

| Placeholder | Source |
|-------------|--------|
| `{Aggregate}` | aggregate.yaml → `name` |
| `{aggregate}` | aggregate name (lowercase) |
| `{rootPackage}` | project-config.json → `rootPackage` |
| `{App}` | Main Application class |
| `{schema}` | project-config.json → `database.environments.test.schema` |
| `{table_name}` | aggregate name (snake_case) |

## Blocking Condition

```
╔════════════════════════════════════════════════════════════════╗
║  ⛔ BLOCKING: Repository Test 必須全部通過                      ║
╠════════════════════════════════════════════════════════════════╣
║  執行: SPRING_PROFILES_ACTIVE=test-outbox mvn test              ║
║        -Dtest={Aggregate}RepositoryTest                         ║
║                                                                 ║
║  ❌ 任何測試失敗 = 停止並修復 Infrastructure                     ║
║  ✅ 全部通過 = 可進入 Step 4.2 (Use Case 產生)                  ║
╚════════════════════════════════════════════════════════════════╝
```
