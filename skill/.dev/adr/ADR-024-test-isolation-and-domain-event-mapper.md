# ADR-024: Test Isolation and DomainEventMapper Management

## Status
Accepted (Updated 2026-01-05)

> **Note**: DomainEventMapperConfig 的實作已在 ADR-047 中更新為 Spring ClassPath Scanning 自動發現機制，不再需要手動列舉每個 Events 類別。

## Context
在實作 Outbox Pattern 的整合測試時，發現測試會出現間歇性失敗的問題。錯誤訊息顯示：
```
Unsupported event for getting mapping: class tw.teddysoft.aiscrum.sprint.entity.SprintEvents$SprintCreated
```

經過深入調查，發現有兩個主要問題：
1. SprintEvents 中的 MemberCapacity 相關事件缺少正確的映射前綴
2. 多個 Mapper 單元測試會修改全局的 DomainEventMapper，造成測試之間的相互干擾

### 問題分析
- **根本原因 1**: SprintEvents.TypeMapper 中 MemberCapacitySet、MemberCapacityReforecasted、MemberCapacityCleared 事件直接使用字串常量，沒有加上 MAPPING_TYPE_PREFIX
- **根本原因 2**: ProductMapperTest、SprintMapperTest、ScrumTeamMapperTest、ProductBacklogItemMapperTest 在 @BeforeAll 中呼叫 `DomainEventMapper.setMapper()`，覆蓋了全局設定
- **影響**: 當測試並行執行或執行順序改變時，Mapper 測試可能會在 Outbox 測試之前執行，導致 DomainEventMapper 的配置不完整

## Decision

### 1. 修正 SprintEvents 事件映射
確保所有事件類型都使用一致的前綴：
```java
public static final String MEMBER_CAPACITY_SET = MAPPING_TYPE_PREFIX + "MemberCapacitySet";
public static final String MEMBER_CAPACITY_REFORECASTED = MAPPING_TYPE_PREFIX + "MemberCapacityReforecasted";
public static final String MEMBER_CAPACITY_CLEARED = MAPPING_TYPE_PREFIX + "MemberCapacityCleared";
```

### 2. 使用 DomainEventMapperConfig 自動註冊（Updated 2026-01-05）

> **重要更新**: 已改為 Spring ClassPath Scanning 自動發現機制，詳見 **ADR-047**。

DomainEventMapper 現在透過 Spring ClassPath Scanning 自動發現所有 `*Events` 介面並註冊：

**位置**: `common/io/springboot/config/DomainEventMapperConfig.java`

```java
@Configuration
public class DomainEventMapperConfig {

    @Bean
    public DomainEventTypeMapper domainEventTypeMapper() {
        // 使用 Spring PathMatchingResourcePatternResolver 自動掃描
        // 所有符合 *Events.class 模式且有 static mapper() 方法的介面
        // 詳見 ADR-047
    }
}
```

**效果**：新增 Aggregate 時只需建立 `*Events.java`，不需要修改 DomainEventMapperConfig。

### 3. Spring Boot 測試自動載入配置
對於 `@SpringBootTest` 測試，Spring 會自動載入 `DomainEventMapperConfig`，不需要額外設定：

> ⚠️ **注意**: 根據 ADR-021，禁止使用 `@ActiveProfiles`。Profile 由 TestSuite 的 ProfileSetter 或環境變數控制。

```java
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)  // 測試隔離
public class SomeIntegrationTest extends BaseUseCaseTest {
    // DomainEventMapperConfig 會自動被 Spring 載入
    // ⛔ 不要使用 @ActiveProfiles - 讓 TestSuite 控制 profile
}
```

詳見：ADR-021: Profile-Based Testing Architecture

### 4. 非 Spring 測試的手動初始化（如需要）
對於不使用 Spring 的單元測試，可以直接呼叫各 Aggregate 的 mapper()：
```java
@BeforeAll
static void setUp() {
    DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
    ProductEvents.mapper().getMap().forEach(mapper::put);
    // ... 其他需要的 Aggregate events
    DomainEventMapper.setMapper(mapper);
}
```

## Consequences

### 正面影響
- **測試隔離性**: 每個測試都能獨立執行，不受其他測試影響
- **一致性**: 所有測試使用相同的 DomainEventMapper 配置
- **可靠性**: 消除了測試執行順序和並行執行造成的間歇性失敗
- **可維護性**: 統一的初始化方式使得測試更容易理解和維護

### 負面影響
- ~~**需要維護配置類別**: 新增 Aggregate 時需要更新 DomainEventMapperConfig~~ （已在 ADR-047 解決）

## Lessons Learned
1. **全局狀態是測試的敵人**: DomainEventMapper 的全局性質造成測試相互干擾
2. **Spring 自動配置優於手動初始化**: 使用 @Configuration + @Bean 讓 Spring 管理初始化
3. **一致性檢查**: 所有事件映射都應該使用統一的前綴和命名規則
4. **測試執行環境差異**: Maven（串行）和 IntelliJ（並行）的執行方式不同，需要考慮並行執行的情況

## Implementation Notes (Updated 2025-01)

**新架構位置**：
- `common/io/springboot/config/DomainEventMapperConfig.java` - 統一的事件映射配置

**舊方式（已棄用）**：
- ~~BootstrapConfig.initialize()~~ - 不再使用

**修改的檔案**（歷史記錄）：
- `SprintEvents.java` - 添加 MemberCapacity 事件的正確映射

## Related ADRs
- ADR-019: Outbox Pattern 實作規範
- ADR-018: Reactor 介面定義
- **ADR-047: Domain Event Auto-Registration with Spring ClassPath Scanning**（更新了 DomainEventMapperConfig 實作）