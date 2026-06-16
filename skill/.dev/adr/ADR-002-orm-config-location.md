# ADR-002 - ORM Configuration Location

## Date
2025-08-01

## Status
Superseded by Aggregate-Specific Config Pattern (2025-01)

## Context
The ORM client interfaces (PlanOrmClient, TagOrmClient) were originally placed in `io.springboot.web.config.orm` package. This placement was questioned because:
- These interfaces are data layer components, not web layer components
- Other configuration classes are directly under `io.springboot.config`
- The `web` package typically contains controllers, filters, and other web-specific components

## Decision (Original - 2025-08)
Move ORM client interfaces from `io.springboot.web.config.orm` to `io.springboot.config.orm`.

## Decision (Updated - 2025-01)
Move ORM client interfaces to aggregate-specific locations: `[aggregate]/io/springboot/config/orm/`.

**New Directory Structure:**
```
src/main/java/tw/teddysoft/aiscrum/
├── common/io/springboot/config/           ← Shared infrastructure
│   ├── SharedInfrastructureConfig.java
│   ├── SharedOutboxConfig.java
│   └── DomainEventMapperConfig.java
│
├── product/io/springboot/config/          ← Product aggregate configs
│   ├── ProductInMemoryRepositoryConfig.java
│   ├── ProductOutboxRepositoryConfig.java
│   ├── ProductUseCaseConfig.java
│   └── orm/
│       └── ProductOrmClient.java
│
├── sprint/io/springboot/config/           ← Sprint aggregate configs
│   └── orm/
│       └── SprintOrmClient.java
│
└── workflow/io/springboot/config/         ← Workflow aggregate configs
    └── orm/
        └── WorkflowOrmClient.java
```

**JPA Configuration Update:**
```java
// 舊配置（已棄用）
@EnableJpaRepositories(basePackages = {
    "tw.teddysoft.aiscrum.io.springboot.config.orm",  // ❌ 集中式
})

// 新配置
@EnableJpaRepositories(basePackages = {
    "tw.teddysoft.aiscrum",  // ✅ 掃描所有 aggregate 下的 ORM clients
    "tw.teddysoft.ezddd.data.io.ezes.store"
})
```

## Consequences

### Positive
- **Parallel Sub-agent Execution**: 不同 aggregate 的配置檔案不會衝突
- **Clear Ownership**: 每個 aggregate 管理自己的 ORM client
- **Git Merge Friendly**: 減少合併衝突
- **Semantic accuracy**: ORM configuration is correctly placed with its aggregate

### Negative
- **Breaking change**: Required updating import statements
- **Migration effort**: Existing projects need to move files

### Neutral
- ORM configuration remains in its own `orm` subdirectory for organization

## Related Decisions
- [ADR-003](./ADR-003-spring-config-structure.md) - Spring Configuration Structure
- Clean Architecture layer separation

## Notes
- This change aligns with "Package by Feature" principle
- Spring Boot component scanning from root package enables this pattern
- Reference: `.ai/tech-stacks/java-ezddd-spring/examples/config/aggregate-specific-config-example.md`

## Implementation History
| Date | Action |
|------|--------|
| 2025-01 | Decision updated to aggregate-specific pattern |
| 2026-01-04 | Synced all documentation files (.ai/tech-stacks/java-ezddd-spring/prompts/, .ai/tech-stacks/java-ezddd-spring/guides/, .ai/tech-stacks/java-ezddd-spring/checklists/, .ai/scripts/, .claude/skills/) to align with this decision |