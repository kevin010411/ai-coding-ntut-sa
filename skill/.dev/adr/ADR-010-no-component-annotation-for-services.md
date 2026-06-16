# ADR-010: 不在 Service 類別使用 @Component 註解

## Status
Accepted

## Context
在開發 ConfigScrumBoardTaskStateUseCase 時，發現 Spring Boot 啟動失敗，因為 ConfigScrumBoardTaskStateService 沒有被註冊為 Spring Bean。團隊需要決定是否應該在 Service 類別上使用 `@Component` 或 `@Service` 註解。

## Decision
我們決定**不在 Use Case Service 實作類別上使用 `@Component` 或 `@Service` 註解**，而是在 `UseCaseConfiguration` 配置類別中明確宣告為 Bean。

### 實作方式

```java
// ❌ 錯誤：Service 類別使用 @Component
@Component  // 不要這樣做！
public class ConfigScrumBoardTaskStateService implements ConfigScrumBoardTaskStateUseCase {
    // ...
}

// ✅ 正確：Service 類別保持 POJO
public class ConfigScrumBoardTaskStateService implements ConfigScrumBoardTaskStateUseCase {
    private final SprintRepository sprintRepository;
    
    public ConfigScrumBoardTaskStateService(SprintRepository sprintRepository) {
        requireNotNull("sprintRepository", sprintRepository);
        this.sprintRepository = sprintRepository;
    }
    // ...
}

// ✅ 正確：在 Aggregate-Specific UseCaseConfig 中宣告 Bean
// 實際命名：[Aggregate]UseCaseConfig（如 SprintUseCaseConfig）
// 檔案位置：[aggregate]/io/springboot/config/[Aggregate]UseCaseConfig.java
@Configuration
public class SprintUseCaseConfig {
    @Bean
    public ConfigScrumBoardTaskStateUseCase configScrumBoardTaskStateUseCase(
            SprintRepository sprintRepository) {
        return new ConfigScrumBoardTaskStateService(sprintRepository);
    }
}
```

## Consequences

### 優點
1. **符合 Clean Architecture 原則**：Service 類別不依賴 Spring 框架註解，保持架構的純淨性
2. **明確的依賴管理**：所有 Bean 宣告集中在配置類別，容易理解和維護
3. **更好的可測試性**：Service 類別是純 POJO，單元測試時不需要 Spring 容器
4. **靈活的配置**：可以根據不同環境或條件創建不同的實作
5. **避免掃描開銷**：減少 Spring 的 component scanning 開銷

### 缺點
1. **需要額外步驟**：每個新的 Service 都需要在 UseCaseConfiguration 中手動註冊
2. **可能忘記註冊**：開發人員可能忘記在配置類別中添加 Bean 宣告

### 影響範圍
- 所有 Use Case Service 實作類別
- 所有 Projection 實作類別
- 所有 Mapper 類別（本來就不應該有 @Component）

## Notes
- 這個決策已經更新到 coding-standards.md、CODE-REVIEW-CHECKLIST.md 和相關的 sub-agent prompts
- 需要確保團隊成員了解這個規範
- 在 code review 時要特別檢查是否遵守這個規範

## Date
2025-08-17

## Author
AI-SCRUM Team