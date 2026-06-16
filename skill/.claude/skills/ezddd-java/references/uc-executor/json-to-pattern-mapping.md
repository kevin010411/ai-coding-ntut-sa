# JSON Spec → Pattern Mapping Reference

> **Version**: 2.0 | **Date**: 2026-02-10
> **Purpose**: Map JSON spec fields to code generation targets

---

## Spec Type Detection (from `uc-workflow.md` Step 0.2)

| Rule | Top-Level Keys | Detected Type |
|------|---------------|---------------|
| 1 | `"useCase"` + `"domainEvent"` | COMMAND |
| 2 | `"query"` | QUERY |
| 3 | `"reactor"` + `"events"` | REACTOR |

COMMAND sub-types (based on `method` field):
- **Constructor**: `method` contains "constructor" → needs `aggregates[]`
- **Method-call**: `method` contains "." → does NOT need `aggregates[]`

> **`domainEvent` format**: accepts both string and array, normalize to array.

---

## Command UseCase Spec Fields

| JSON Field | Code Generation Target | Pattern File |
|------------|----------------------|-------------|
| `spec.useCase` | UseCase interface name | `patterns/usecase/command.md` |
| `spec.behavior` | Javadoc on UseCase | — |
| `spec.aggregate` | Aggregate class name | `patterns/domain/aggregate.md` |
| `spec.aggregateId` | AggregateId value object | `patterns/domain/value-object.md` |
| `spec.method` | Aggregate method to invoke | — |
| `spec.domainEvent` | Event record name | `patterns/domain/domain-event.md` |
| `spec.repository` | Repository dependency name | — |
| `spec.input[]` | `Input` inner class fields | `patterns/usecase/command.md` |
| `spec.output` | Return type description | — |
| `spec.aggregates[]` | Aggregate Root class | `patterns/domain/aggregate.md` |
| `spec.aggregates[].attributes[]` | Aggregate fields + PO columns | `patterns/infrastructure/persistent-object.md` |
| `spec.aggregates[].attributes[].constraint` | Field initialization logic | — |
| `spec.domainEvents[]` | Sealed interface + records | `patterns/domain/domain-event.md` |
| `spec.domainEvents[].attributes[]` | Event record parameters | — |
| `spec.entities[]` | Entity classes | `patterns/domain/entity.md` |
| `spec.valueObjects[]` | Record types | `patterns/domain/value-object.md` |
| `spec.enums[]` | Enum definitions | — |
| `spec.constructorPreconditions[]` | `requireNotNull()` checks | `patterns/testing/contract-test.md` |
| `spec.constructorPostconditions[]` | `ensure()` checks + event verification | `patterns/testing/contract-test.md` |
| `spec.domainModelNotes[]` | Design context (informational) | — |

---

## Query UseCase Spec Fields

| JSON Field | Code Generation Target | Pattern File |
|------------|----------------------|-------------|
| `spec.query` | Query UseCase interface name | `patterns/usecase/query.md` |
| `spec.behavior` | Javadoc on UseCase | — |
| `spec.input[]` | `Input` inner class fields | `patterns/usecase/query.md` |
| `spec.output` | Output class name | — |
| `spec.dependencies[]` | Repository dependencies used to load aggregate/entity state | — |
| `spec.readOnlyEntities[]` | Read-only entity classes/views used as query result models | `patterns/usecase/query.md`, `patterns/domain/entity.md` |
| `spec.readOnlyEntities[].source` | Mutable aggregate/entity protected by the read-only view | — |
| `spec.readOnlyEntities[].queryMethods[]` | Public read methods to expose | — |
| `spec.readOnlyEntities[].blockedCommandMethods[]` | State-changing methods to reject | — |
| `spec.readOnlyEntities[].rules[]` | Encapsulation and immutable collection rules | — |
| `spec.testDataSetup` | Test setup steps | `patterns/testing/usecase-test.md` |
| `spec.testScenarios[]` | Test methods | `patterns/testing/usecase-test.md` |
| `spec.testScenarios[].given[]` | Test precondition setup | — |
| `spec.testScenarios[].when` | Test action | — |
| `spec.testScenarios[].then[]` | Assertions | — |

---

## Reactor Spec Fields

| JSON Field | Code Generation Target | Pattern File |
|------------|----------------------|-------------|
| `spec.reactor` | Reactor interface name | `patterns/usecase/reactor.md` |
| `spec.service` | Service class name | — |
| `spec.interface_location` | Interface package path | — |
| `spec.service_location` | Service package path | — |
| `spec.events[]` | Subscribed event types | — |
| `spec.events[].source` | Full event class path | — |
| `spec.events[].fields[]` | Event payload access | — |
| `spec.dependencies[]` | Injected dependencies | — |
| `spec.inquiries[]` | Inquiry interface + impls | `patterns/usecase/query.md` |
| `spec.inquiries[].queryLogic` | JPA query implementation | — |
| `spec.actions[]` | Service method body | — |
| `spec.errorHandling[]` | Error handling strategy | — |
| `spec.testScenarios[]` | Test methods | `patterns/testing/usecase-test.md` |

---

## Important Notes

### Mapper Location (QUERY — CRITICAL)
- **Must respect `spec.mappers[].location` field** — typically `usecase.port`
- Wrong package placement = Gate 2.5 violation
