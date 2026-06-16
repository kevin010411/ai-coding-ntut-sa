# ADR-001 - UseCase Package Structure

## Date
2025-08-01

## Status
Accepted

## Context
The project uses Clean Architecture with CQRS pattern, resulting in three types of use cases:
- Commands (17 use cases): Operations that modify state
- Queries (6 use cases): Operations that retrieve data
- Reactors (1 use case): Event-driven operations across aggregates

The question arose whether to subdivide the `usecase.port.in` package into `command`, `query`, and `reactor` subdirectories to better organize these different types.

## Decision
Maintain the current flat structure where Command and Query use cases coexist in `usecase.port.in`, while keeping Reactor in its own `usecase.port.in.reactor` subdirectory.

## Consequences

### Positive
- **Simplicity**: Flat structure is easier to navigate and understand
- **Consistency**: Aligns with common DDD project conventions
- **Clear naming**: UseCase names already indicate their type (Create*, Get*, etc.)
- **Flexibility**: Easy to find and refactor use cases without navigating deep hierarchies
- **IDE support**: Modern IDEs can filter by type using inheritance

### Negative
- **No explicit separation**: Commands and Queries are mixed in the same package
- **Potential growth issues**: May become cluttered if use cases grow significantly

### Neutral
- Developers need to rely on naming conventions and extends clauses to identify use case types

## Alternatives Considered

### Option 1: Subdivide into command/query/reactor packages
- **Description**: Create `usecase.port.in.command`, `usecase.port.in.query`, `usecase.port.in.reactor`
- **Pros**: Explicit separation by CQRS concern, clearer organization
- **Cons**: Deeper package hierarchy, more navigation overhead
- **Reason for rejection**: Current scale (23 use cases) doesn't justify the added complexity

### Option 2: Separate by aggregate then by type
- **Description**: `plan.usecase.port.in.command`, `plan.usecase.port.in.query`, etc.
- **Pros**: Very explicit organization
- **Cons**: Extremely deep hierarchy, difficult navigation
- **Reason for rejection**: Over-engineering for current project size

## Related Decisions
- Clean Architecture adoption
- CQRS pattern implementation
- Package-by-feature structure

## Notes
- Reactor already has its own subdirectory because it handles cross-aggregate concerns
- If the project grows to 50+ use cases per aggregate, reconsider this decision
- The `extends` keyword makes it easy to identify use case types programmatically