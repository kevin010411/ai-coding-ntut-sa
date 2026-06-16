# ADR-003 - Spring Configuration Structure

## Date
2025-08-01

## Status
Accepted

## Context
A suggestion was made to create an `io.springboot.config.di` package to house all Bean declaration files. Currently, we have:
- 5 configuration classes in `io.springboot.config`
- 41 total Bean declarations across these classes
- Each class averages about 8 Bean declarations
- Classes are organized by functional area (DataSource, Repository, UseCase, etc.)

## Decision
Maintain the current flat structure in `io.springboot.config` without creating a separate `di` subdirectory.

## Consequences

### Positive
- **Spring Boot conventions**: Aligns with standard Spring Boot project structure
- **Functional organization**: Configuration classes are grouped by what they configure, not how
- **Simple navigation**: Developers can easily find configuration by domain concern
- **Clear naming**: `*Config` suffix already indicates these are configuration classes
- **Avoiding over-engineering**: Current scale doesn't warrant additional hierarchy

### Negative
- **No explicit DI grouping**: Bean declarations are spread across multiple files
- **Potential future growth**: May need reorganization if configuration grows significantly

### Neutral
- Developers need to understand Spring's @Configuration convention
- Bean declarations remain close to their functional context

## Alternatives Considered

### Option 1: Create config.di package
- **Description**: Move all @Configuration classes to `io.springboot.config.di`
- **Pros**: Explicit grouping of DI configuration
- **Cons**: DI is an implementation detail, breaks functional grouping
- **Reason for rejection**: Violates principle of organizing by business capability, not technical mechanism

### Option 2: Subdivide by technical layer
- **Description**: Create `config.web`, `config.data`, `config.domain`, etc.
- **Pros**: Technical layer separation
- **Cons**: Premature optimization for current project size
- **Reason for rejection**: Current 5 configuration classes don't justify subdivision

### Option 3: One configuration class per aggregate
- **Description**: PlanConfig, TagConfig, etc.
- **Pros**: Strong cohesion within aggregates
- **Cons**: Would create many small configuration classes
- **Reason for rejection**: Would fragment related configurations (e.g., repositories)

## Related Decisions
- [ADR-002](./ADR-002-orm-config-location.md) - ORM Configuration Location
- Spring Boot adoption
- Clean Architecture implementation

## Notes
- If configuration classes grow to 10+ files, consider functional subdivision (e.g., `config.web`, `config.persistence`)
- Never organize by technical implementation details (e.g., `config.di`, `config.annotations`)
- The `orm` subdirectory under config is acceptable because it groups a specific technical concern
- Current structure has proven maintainable with 41 beans across 5 classes