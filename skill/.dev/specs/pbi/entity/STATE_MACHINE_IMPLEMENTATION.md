# ProductBacklogItem State Machine Implementation

## Overview
This document describes the state machine implementation for ProductBacklogItem based on the specification requirements.

## State Definitions (PbiState)
- **BACKLOGGED**: Not selected into any Sprint
- **SELECTED**: Selected into a Sprint (but Sprint hasn't started)
- **IN_PROGRESS**: Sprint has started (regardless of Task completion status)
- **DONE**: All Tasks are DONE and AC/DoD are met
- **CANCELED**: Cancelled (not implemented in this phase)

## State Transitions

### 1. SELECTED → IN_PROGRESS
**Trigger**: `startSprint(SprintId sprintId, String by)`
**Conditions**: 
- PBI must be in SELECTED state
- PBI must be committed to the specified Sprint
**Event**: `PbiBecameInProgress`

### 2. IN_PROGRESS → DONE
**Trigger**: Task movement via `moveTask(TaskId taskId, ScrumBoardTaskState newState, String movedBy)`
**Conditions**: 
- PBI must be in IN_PROGRESS state
- All tasks must be DONE after the move
- Acceptance criteria must be met
- Definition of done must be met
**Event**: `PbiCompleted`

### 3. DONE → IN_PROGRESS (Regression)
**Trigger**: Task movement via `moveTask(TaskId taskId, ScrumBoardTaskState newState, String movedBy)`
**Conditions**: 
- PBI was in DONE state before the task move
- At least one task is not DONE after the move
**Event**: `PbiWorkRegressed`

## New Events Added

### PbiBecameInProgress
```java
record PbiBecameInProgress(
    ProductId productId,
    SprintId sprintId,
    PbiId pbiId,
    PbiState previousState,
    PbiState newState,
    String startedBy,
    // ... metadata fields
)
```

### PbiCompleted
```java
record PbiCompleted(
    ProductId productId,
    SprintId sprintId,
    PbiId pbiId,
    PbiState previousState,
    PbiState newState,
    String completedBy,
    // ... metadata fields
)
```

### PbiWorkRegressed
```java
record PbiWorkRegressed(
    ProductId productId,
    SprintId sprintId,
    PbiId pbiId,
    PbiState previousState,
    PbiState newState,
    String regressedBy,
    String reason,
    // ... metadata fields
)
```

## New Methods Added

### startSprint()
Transitions a SELECTED PBI to IN_PROGRESS when a Sprint starts.

### Helper Methods
- `allTasksDone()`: Check if all tasks are in DONE state
- `anyTaskNotDone()`: Check if any task is not in DONE state
- `acceptanceCriteriaMet()`: Check if acceptance criteria are met (default: true)
- `definitionOfDoneMet()`: Check if definition of done is met (default: true)
- `willAllTasksBeDoneAfterMove()`: Predict task state after a move
- `willAnyTaskBeNotDoneAfterMove()`: Predict if any task would not be done after a move

## Updated Methods

### moveTask()
Enhanced to handle PBI state transitions:
1. Applies TaskMoved event
2. Checks for completion (IN_PROGRESS → DONE)
3. Checks for regression (DONE → IN_PROGRESS)
4. Applies appropriate state transition events

### ensureInvariant()
Enhanced to handle transient states during event application by relaxing the "DONE PBI must have all tasks DONE" invariant when state transition events are pending.

## Key Design Decisions

1. **Event Ordering**: TaskMoved events are applied before state transition events to maintain proper event sequencing.

2. **Predictive Logic**: Helper methods predict the final state after task moves to determine if state transitions are needed.

3. **Invariant Relaxation**: The strict invariant checking is relaxed during state transitions to allow for transient inconsistencies that are resolved by subsequent events.

4. **Default AC/DoD**: Acceptance criteria and definition of done checking currently returns `true` by default, allowing for future enhancement with specific business rules.

## Test Coverage
- State transition from SELECTED to IN_PROGRESS
- State transition from IN_PROGRESS to DONE when all tasks completed
- State regression from DONE to IN_PROGRESS when tasks move back
- Helper methods validation
- Event generation verification