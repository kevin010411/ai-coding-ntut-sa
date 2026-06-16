# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records (ADRs) - documents that capture important architectural and design decisions made during the development of the AI-Plan project.

## Why ADRs?

- **Knowledge Preservation**: Captures the context and reasoning behind decisions
- **Team Alignment**: Helps team members understand why certain choices were made
- **Future Reference**: Provides historical context for future modifications
- **Onboarding**: Helps new team members understand the system design

## ADR Format

Each ADR follows this structure:

1. **Title**: ADR-[number] - [descriptive title]
2. **Date**: When the decision was made
3. **Status**: Proposed/Accepted/Deprecated/Superseded
4. **Context**: What prompted this decision
5. **Decision**: What we decided to do
6. **Consequences**: The implications of this decision
7. **Alternatives Considered**: Other options we evaluated

- [ADR-018](./ADR-018-pbi-state-transition-invariant-handling.md) - PBI State Transition Invariant Handling
## Contributing

When making significant architectural decisions:

1. Copy the template from `ADR-template.md`
2. Create a new file with the next number in sequence
3. Fill in all sections
4. Submit for review along with your implementation

## References

- [Architecture Decision Records](https://adr.github.io/)
