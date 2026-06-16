# False Positive Avoidance Rules

## Rule 1: cross_frame_concerns Do NOT Require Use Case/Aggregate Implementation

```
AUDIT POLICY: Cross-Frame Concerns

IF scenario.trace.frame_concerns includes a concern from cross_frame_concerns
AND that concern has binding.adapter_hint (e.g., controller.yaml#security)
THEN:
  - DO NOT flag "missing implementation in Service/Aggregate"
  - DO NOT flag "missing test in usecase tier"
  - INSTEAD verify: adapter layer evidence (annotation/config)
  - INSTEAD verify: integration test evidence (if test_tier: integration)

EXAMPLE:
  cross_frame_concerns: [WF-FC-AUTH]
  WF-FC-AUTH.binding.adapter_hint: controller.yaml#security
  scenario.test_tier: integration
  -> This is NOT a missing implementation; it's deferred to integration tier
```

## Rule 2: test_tier: integration Scenarios Do NOT Require usecase-layer Tests

| Scenario Attribute | Expected Evidence | False Positive If |
|--------------------|-------------------|-------------------|
| `test_tier: usecase` (default) | `{UseCase}ServiceTest.java` | Missing test flagged - correct |
| `test_tier: integration` | Integration test (future) | Missing usecase test flagged - FALSE POSITIVE |
| `test_tier: contract` | `{Aggregate}ContractTest.java` | Missing usecase test flagged - FALSE POSITIVE |

## Rule 3: Transport-level vs Domain Authorization

| Authorization Type | Location | Test Tier | Flag as Missing? |
|--------------------|----------|-----------|------------------|
| Framework auth (JWT, @PreAuthorize) | Controller/Filter | integration | NO |
| Domain auth ("only owner can delete") | Use Case/Aggregate | usecase/contract | YES |

**Detection Heuristic:**
- If concern ID contains "AUTH" and is in `cross_frame_concerns` -> Framework auth (defer)
- If concern is in `frame_concerns` with domain rule -> Domain auth (require impl)

## Invariant Test Strategy

Class Invariants (INV-N) are **aggregate-level** constraints, NOT per-method constraints.
- The uContract framework automatically calls `ensureInvariant()` on **every public method entry**
- If **any one operation** tests an invariant, **all other operations are covered**
- Do NOT flag as a gap if INV-1 is tested by one method but not by others

```
FALSE POSITIVE: "rename() tests INV-1 but changeNote() doesn't -> GAP"
CORRECT:        "INV-1 tested once via rename() -> covers all operations -> NOT A GAP"
```
