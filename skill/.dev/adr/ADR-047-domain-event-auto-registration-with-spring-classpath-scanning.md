# ADR-047: Domain Event Auto-Registration with Spring ClassPath Scanning

## Status
Accepted (2026-01-05)

## Context

在實作 Problem Frame Executor 的平行執行時，發現 `DomainEventMapperConfig.java` 是一個共用檔案，當多個 sub-agents 同時為不同 Aggregates 產生程式碼時，可能會產生衝突。

### 原有設計的問題

原本的 `DomainEventMapperConfig` 需要手動列舉每個 Aggregate 的 Events：

```java
// 舊版：需要手動維護
@Bean
public DomainEventTypeMapper domainEventTypeMapper() {
    DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
    ProductEvents.mapper().getMap().forEach(mapper::put);      // 手動加
    SprintEvents.mapper().getMap().forEach(mapper::put);       // 手動加
    ProductBacklogItemEvents.mapper().getMap().forEach(mapper::put);  // 手動加
    // ... 每新增一個 Aggregate 都要改這裡
    return mapper;
}
```

**問題**：
1. 每次新增 Aggregate 都需要修改此檔案
2. 多個 sub-agents 平行執行時可能產生 merge conflict
3. 容易遺漏註冊新的 Events

### 評估的替代方案

| 方案 | 優點 | 缺點 |
|------|------|------|
| **Marker Interface** | 明確標記 | Domain Layer 需要新增介面 |
| **Java SPI (ServiceLoader)** | 純 Java，無框架依賴 | 需要維護 META-INF/services/ |
| **org.reflections library** | 功能強大 | 已停止維護（2022） |
| **ClassGraph** | 活躍維護 | 需要額外依賴 |
| **Spring ClassPath Scanning** | 零額外依賴 | 依賴 Spring |

## Decision

採用 **Spring ClassPath Scanning** 實現自動註冊，理由：
1. 專案已經使用 Spring Boot，不需要額外依賴
2. `PathMatchingResourcePatternResolver` 是 Spring 內建的穩定 API
3. 利用命名慣例（`*Events.class`）自動發現，無需 Marker 介面

### 新設計

```java
@Configuration
public class DomainEventMapperConfig {

    private static final String BASE_PACKAGE_PATH =
        "classpath*:tw/teddysoft/aiscrum/**/*Events.class";

    @Bean
    public DomainEventTypeMapper domainEventTypeMapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();

        PathMatchingResourcePatternResolver resolver =
            new PathMatchingResourcePatternResolver();
        Resource[] resources = resolver.getResources(BASE_PACKAGE_PATH);

        for (Resource resource : resources) {
            // 載入類別，檢查是否為介面且有 static mapper() 方法
            // 自動註冊所有符合條件的 Events
        }

        return mapper;
    }
}
```

### 自動發現的條件

一個 Events 類別要被自動發現，必須符合：
1. 類別名稱符合 `*Events` 模式
2. 是頂層介面（非 inner class）
3. 繼承 `InternalDomainEvent`
4. 有 `static DomainEventTypeMapper mapper()` 方法

## Consequences

### 正面影響

1. **零衝突**：`DomainEventMapperConfig` 不再需要修改，完全消除平行執行衝突
2. **零額外依賴**：使用 Spring 內建 API，不需要新增 library
3. **自動發現**：新增 Aggregate 只需建立 `*Events.java`，無需其他配置
4. **Clean Architecture 相容**：Domain Layer 不需要任何修改

### 負面影響

1. **命名慣例依賴**：Events 類別必須以 `Events` 結尾
2. **啟動時掃描**：有微小的啟動時間開銷（約 30-50ms）
3. **隱式註冊**：不像手動列舉那樣明確

## Implementation Notes

### 修改的檔案

1. `common/io/springboot/config/DomainEventMapperConfig.java` - 使用 Spring ClassPath Scanning
2. `pom.xml` - 移除 org.reflections 依賴（如果之前加過）

### 新增 Aggregate 的流程

**之前**：
1. 建立 `NewEvents.java`
2. 修改 `DomainEventMapperConfig.java` 加一行

**現在**：
1. 建立 `NewEvents.java`（只需這一步！）

### Log 輸出範例

```
INFO DomainEventMapperConfig : Registered 64 domain event types from 6 Events interfaces
```

## Related ADRs

- ADR-024: Test Isolation and DomainEventMapper Management（此 ADR 更新了 DomainEventMapperConfig 的設計）
- ADR-002: Aggregate-Specific Configuration Pattern（平行執行的配置隔離策略）
