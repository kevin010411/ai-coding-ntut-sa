# ADR-019: Outbox Pattern Implementation

## 狀態
已實施 (Implemented)

## 日期
2025-08-23

## 背景 (Context)
專案需要實作可靠的事件發布機制，確保領域事件與業務資料的一致性。傳統的「雙寫問題」（同時寫入資料庫和發布事件）可能導致資料不一致。Outbox Pattern 提供了一個經過驗證的解決方案。

## 決策 (Decision)
採用 Outbox Pattern 實作事件發布，使用 ezddd-gateway 框架提供的 OutboxRepository 機制。

## 實作架構

### 1. 核心組件結構
```
[Aggregate]
    ├── entity/                    # 領域實體
    ├── usecase/
    │   └── port/
    │       ├── [Aggregate]Mapper.java    # 包含 OutboxMapper 內部類別
    │       └── out/
    │           └── [Aggregate]Data.java  # 實作 OutboxData<String>
    └── io.springboot.config/
        └── orm/
            └── [Aggregate]OrmClient.java  # 繼承 SpringJpaClient
```

### 2. 關鍵實作步驟

#### Step 1: 建立 Data 類別
每個 Aggregate 需要對應的 Data 類別，實作 `OutboxData<String>` 介面：

```java
package tw.teddysoft.aiscrum.[aggregate].usecase.port.out;

@Entity
@Table(name = "[aggregate]")
public class [Aggregate]Data implements OutboxData<String> {
    
    @Transient  // 關鍵：必須標記為 Transient
    private List<DomainEventData> domainEventDatas;
    
    @Transient  // 關鍵：必須標記為 Transient
    private String streamName;
    
    @Id
    private String [aggregate]Id;
    
    @Version  // 樂觀鎖版本控制
    private long version;
    
    // 實作 OutboxData 介面方法
    @Override
    @Transient
    public String getId() { return [aggregate]Id; }
    
    @Override
    @Transient
    public List<DomainEventData> getDomainEventDatas() {
        return this.domainEventDatas;
    }
    
    // ... 其他必要方法
}
```

#### Step 2: 實作 Mapper 類別
Mapper 必須包含 OutboxMapper 內部類別：

```java
package tw.teddysoft.aiscrum.[aggregate].usecase.port;

public class [Aggregate]Mapper {
    
    private static OutboxMapper mapper = new [Aggregate]Mapper.Mapper();
    
    public static OutboxMapper newMapper() {
        return mapper;
    }
    
    public static [Aggregate]Data toData([Aggregate] aggregate) {
        // 實作領域物件轉換為資料物件
        // 關鍵：必須設定 domainEventDatas 和 streamName
        data.setDomainEventDatas(aggregate.getDomainEvents().stream()
            .map(DomainEventMapper::toData)
            .collect(Collectors.toList()));
        data.setStreamName(aggregate.getStreamName());
    }
    
    public static [Aggregate] toDomain([Aggregate]Data data) {
        // 實作資料物件轉換為領域物件
        // 關鍵：優先從事件重建，無事件時從當前狀態重建
        if (data.getDomainEventDatas() != null && !data.getDomainEventDatas().isEmpty()) {
            // 從事件重建
            var domainEvents = data.getDomainEventDatas().stream()
                .map(DomainEventMapper::toDomain)
                .map(event -> ([Aggregate]Events) event)
                .collect(Collectors.toList());
            
            [Aggregate] aggregate = new [Aggregate](domainEvents);
            aggregate.setVersion(data.getVersion());
            aggregate.clearDomainEvents();
            return aggregate;
        } else {
            // 從當前狀態重建
        }
    }
    
    // 關鍵：必須是內部類別，不可為獨立類別
    static class Mapper implements OutboxMapper<[Aggregate], [Aggregate]Data> {
        @Override
        public [Aggregate] toDomain([Aggregate]Data data) {
            return [Aggregate]Mapper.toDomain(data);
        }
        
        @Override
        public [Aggregate]Data toData([Aggregate] aggregateRoot) {
            return [Aggregate]Mapper.toData(aggregateRoot);
        }
    }
}
```

#### Step 3: 建立 OrmClient 介面
```java
// OrmClient 放在對應 aggregate 的 io/springboot/config/orm/ 目錄下
package tw.teddysoft.aiscrum.[aggregate].io.springboot.config.orm;

public interface [Aggregate]OrmClient extends SpringJpaClient<[Aggregate]Data, String> {
    // 不需要任何實作，Spring Data JPA 會自動產生
}
```

#### Step 4: 配置基礎設施（SharedOutboxConfig）

⚠️ **CRITICAL: 必須包含以下 JPA 配置註解，否則會導致 ApplicationContext 載入失敗！**

> 檔案位置：`common/io/springboot/config/SharedOutboxConfig.java`

```java
@Configuration
@Profile({"outbox", "test-outbox"})  // 使用 Profile 進行條件啟用
@EnableTransactionManagement  // 🔴 必須！否則會出現 TransactionRequiredException
@EnableJpaRepositories(basePackages = {
    "{rootPackage}",                             // 🔴 掃描所有 aggregate 的 ORM clients（在 [aggregate]/io/springboot/config/orm/）
    "tw.teddysoft.ezddd.data.io.ezes.store"      // 🔴 必須！掃描 ezddd 框架的 PgMessageDbClient
})
@EntityScan(basePackages = {
    "{rootPackage}.{aggregate}.usecase.port.out", // 🔴 專案的 Data classes
    "tw.teddysoft.ezddd.data.io.ezes.store"       // 🔴 必須！掃描 ezddd 框架的 MessageData entity
})
public class SharedOutboxConfig {  // 共用 JPA 基礎設施

    @PersistenceContext  // 🔴 必須使用 @PersistenceContext，不是 @Autowired
    private EntityManager entityManager;

    @Bean
    public PgMessageDbClient pgMessageDbClient() {
        // 🔴 必須使用 JpaRepositoryFactory 建立，不能直接 new
        RepositoryFactorySupport factory = new JpaRepositoryFactory(entityManager);
        return factory.getRepository(PgMessageDbClient.class);
    }

    // ... 其他共用 beans
}
```

#### Step 5: 配置 Repository（Aggregate-Specific 模式）

> ⚠️ **ezapp 2.0.0 更新**：使用 Aggregate-Specific 配置模式。
> 參考：`.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/`

```java
// 檔案位置: [aggregate]/io/springboot/config/[Aggregate]OutboxRepositoryConfig.java
@Configuration
@Profile({"outbox", "test-outbox"})
public class [Aggregate]OutboxRepositoryConfig {

    @Bean("[aggregate]OutboxRepository")  // 明確命名
    public Repository<[Aggregate], [Aggregate]Id> [aggregate]OutboxRepository(
            [Aggregate]OrmClient ormClient,
            MessageDbClient messageDbClient) {
        EzOutboxClient<[Aggregate]Data, String> outboxClient =
            new EzOutboxClient<>(ormClient, messageDbClient);
        OutboxStore<[Aggregate]Data, String> outboxStore =
            EzOutboxStoreAdapter.createOutboxStore(outboxClient);
        OutboxRepositoryPeer<[Aggregate]Data, String> peer =
            new OutboxRepositoryPeer<>(outboxStore);  // v2.0.0: 已改名
        return new OutboxRepository<>(peer, [Aggregate]Mapper.newMapper());
    }
}
```

## 重要注意事項

### 1. 必須遵守的規範
- ❗ **@Transient 標註**：`domainEventDatas` 和 `streamName` 必須標記為 `@Transient`
- ❗ **內部類別 Mapper**：OutboxMapper 必須是 Mapper 的內部類別，不可為獨立類別
- ❗ **套件位置**：
  - Data 類別必須在 `[aggregate]/usecase/port/out/`
  - Mapper 必須在 `[aggregate]/usecase/port/`
  - OrmClient 必須在 `[aggregate]/io/springboot/config/orm/`
- ❗ **版本控制**：Data 類別必須有 `@Version` 欄位支援樂觀鎖

### 2. Jakarta EE 遷移
從 Spring Boot 3.x 開始，必須使用 `jakarta.persistence.*` 而非 `javax.persistence.*`：
```java
// ❌ 錯誤
import javax.persistence.*;

// ✅ 正確
import jakarta.persistence.*;
```

### 3. 版本號處理
Outbox pattern 中，新建立的 aggregate 版本號從 0 開始是正常的：
```java
// 測試中應接受 version >= 0
assertTrue(aggregate.getVersion() >= 0);  // ✅ 正確
// 而非
assertEquals(1L, aggregate.getVersion());  // ❌ 可能失敗
```

### 4. 時間戳記一致性
建議統一使用一種時間戳記方式：
```java
// 選擇其一並保持一致
DateProvider.now()  // 或
Instant.now()
```

### 5. Profile 啟用策略
- 開發環境：使用 `default` profile（In-Memory Repository）
- 測試環境：使用 `outbox` profile（測試 Outbox 功能）
- 生產環境：使用 `outbox,production` profile 組合

### 6. 測試策略

#### 🔴 必要測試要求
**每個實作 OutboxRepository 的 Aggregate 都必須包含完整的整合測試**。這是強制性要求，不是選擇性的。

所有 OutboxRepository 都必須包含以下標準測試案例：
1. **資料持久化測試** - 驗證所有欄位正確儲存到資料庫
2. **資料讀取測試** - 驗證從資料庫讀取的完整性
3. **軟刪除測試** - 驗證使用 `save()` 而非 `delete()` 執行軟刪除
4. **版本控制測試** - 驗證樂觀鎖機制

參考範例：`.ai/tech-stacks/java-ezddd-spring/examples/outbox/ProductOutboxRepositoryTest.java`

#### 測試配置

> ⚠️ **注意**: 根據 ADR-021，禁止使用 `@ActiveProfiles`。Profile 由 TestSuite 的 ProfileSetter 或環境變數控制。

```java
@SpringBootTest
@Transactional  // 每個測試後自動 rollback
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)  // 測試隔離
@EzFeature  // 使用 ezSpec BDD 測試框架
@EzFeatureReport
public class YourOutboxRepositoryTest extends BaseUseCaseTest {
    // 實作標準測試案例
    // ⛔ 不要使用 @ActiveProfiles - 讓 TestSuite 控制 profile
}
```

**Profile 控制方式**:
1. 使用 TestSuite 的 ProfileSetter 類別（推薦）
2. 使用環境變數：`SPRING_PROFILES_ACTIVE=test-outbox mvn test`

詳見：
- ADR-021: Profile-Based Testing Architecture
- `.dev/lessons/JUNIT-SUITE-PROFILE-SWITCHING.md`

#### 測試資料庫配置

⚠️ **CRITICAL: 必須設定 `hibernate.default_schema`，否則 Hibernate 找不到 message_store schema 的 table！**

```properties
# application-test-outbox.properties

# Database connection (參考 .dev/project-config.json)
spring.datasource.url=jdbc:postgresql://localhost:5800/board?currentSchema=message_store
spring.datasource.username=postgres
spring.datasource.password=root
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA/Hibernate settings
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

# 🔴 CRITICAL: 必須設定 default_schema，否則 Hibernate 無法正確操作 message_store schema
spring.jpa.properties.hibernate.default_schema=message_store
```

#### 測試清理設定

⚠️ **測試之間必須清理 messages table，否則事件會累積導致測試互相影響！**

```java
@Autowired(required = false)
private JdbcTemplate jdbcTemplate;

@Value("${spring.profiles.active:test-inmemory}")
private String activeProfile;

@BeforeEach
void setUp() {
    // 🔴 CRITICAL: Outbox profile 必須清理 messages table
    if (activeProfile.contains("outbox")) {
        if (jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("DELETE FROM message_store.messages");
                jdbcTemplate.execute("ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1");
                System.out.println("✅ Cleaned up message_store.messages table");
            } catch (Exception e) {
                System.err.println("⚠️ Could not clean messages table: " + e.getMessage());
            }
        }
    }

    // 其他測試設定...
}
```

## 常見錯誤與解決

### 錯誤 1：缺少 JPA 配置註解
```java
// ❌ 錯誤：缺少必要的 JPA 註解
@Configuration
@Profile({"outbox", "test-outbox"})
public class SharedOutboxConfig {
    // 會導致 "Not a managed type: MessageData" 或 TransactionRequiredException
}

// ✅ 正確：包含所有必要註解（位於 common/io/springboot/config/）
@Configuration
@Profile({"outbox", "test-outbox"})
@EnableTransactionManagement
@EnableJpaRepositories(basePackages = {
    "{rootPackage}",                         // ORM clients 在 [aggregate]/io/springboot/config/orm/
    "tw.teddysoft.ezddd.data.io.ezes.store"  // 🔴 必須掃描 ezddd framework
})
@EntityScan(basePackages = {
    "{rootPackage}.{aggregate}.usecase.port.out",
    "tw.teddysoft.ezddd.data.io.ezes.store"  // 🔴 必須掃描 ezddd framework
})
public class SharedOutboxConfig {
    // ...
}
```

### 錯誤 2：缺少 Hibernate default_schema
```properties
# ❌ 錯誤：沒有設定 default_schema
spring.datasource.url=jdbc:postgresql://localhost:5800/board?currentSchema=message_store

# ✅ 正確：必須同時設定 default_schema
spring.datasource.url=jdbc:postgresql://localhost:5800/board?currentSchema=message_store
spring.jpa.properties.hibernate.default_schema=message_store
```

### 錯誤 3：獨立的 OutboxMapper 類別
```java
// ❌ 錯誤：獨立類別
public class SprintOutboxMapper {
    // ...
}

// ✅ 正確：內部類別
public class SprintMapper {
    static class Mapper implements OutboxMapper<Sprint, SprintData> {
        // ...
    }
}
```

### 錯誤 2：缺少 @Transient 標註
```java
// ❌ 錯誤：沒有 @Transient
private List<DomainEventData> domainEventDatas;

// ✅ 正確：加上 @Transient
@Transient
private List<DomainEventData> domainEventDatas;
```

### 錯誤 3：錯誤的套件位置
```java
// ❌ 錯誤
package tw.teddysoft.aiscrum.sprint.adapter.out.mapper;

// ✅ 正確
package tw.teddysoft.aiscrum.sprint.usecase.port;
```

## 效益 (Consequences)

### 優點
- ✅ **交易一致性**：業務資料和事件在同一交易中提交
- ✅ **可靠性保證**：事件不會因系統故障而遺失
- ✅ **順序保證**：透過序號確保事件按正確順序發布
- ✅ **可觀測性**：所有事件都有記錄，便於審計和除錯
- ✅ **冪等性支援**：每個事件有唯一 ID，避免重複處理

### 缺點
- ⚠️ **複雜度增加**：需要額外的 Data、Mapper、OrmClient 類別
- ⚠️ **延遲發布**：事件非同步發布，有輪詢延遲
- ⚠️ **資料庫負載**：Outbox 表會持續增長，需要清理策略

## 參考資料
- [Outbox Pattern 實作指南](.ai/tech-stacks/java-ezddd-spring/examples/outbox/README.md)
- [ezddd-gateway 文件](https://github.com/teddy-chen/ezddd-gateway)
- [Microservices.io - Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html)

## 修訂歷史
- 2025-08-23：初始版本，記錄 Outbox Pattern 實作過程與注意事項
- 2025-12-11：新增關鍵 JPA 配置要求（@EnableTransactionManagement, @EnableJpaRepositories, @EntityScan 必須掃描 ezddd framework package）、Hibernate default_schema 設定、測試清理 messages table 的說明