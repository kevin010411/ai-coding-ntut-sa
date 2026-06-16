# Complex Aggregate Specification Template

## Overview
This template helps you specify complex aggregates with multiple entities for LLM code generation. Use this when creating aggregates that contain nested entities, such as Workflow containing Lanes, where Lanes can be Stages or Swimlanes.

## Template Structure

### 1. Aggregate Overview
```yaml
aggregate:
  name: [AggregateRootName]
  description: [Business purpose and responsibility]
  bounded_context: [Context name]
  invariants:
    - [Business rule 1 that must always be true]
    - [Business rule 2 that must always be true]
```

### 2. Entity Hierarchy
```yaml
entities:
  root:
    name: [AggregateRootName]
    id_type: [IdType]
    properties:
      - name: [propertyName]
        type: [type]
        description: [purpose]
        constraints: [validation rules]
    
  children:
    - name: [EntityName]
      parent: [ParentEntityName]
      id_type: [IdType or embedded]
      cardinality: [one-to-one | one-to-many]
      properties:
        - name: [propertyName]
          type: [type]
          description: [purpose]
      invariants:
        - [Entity-specific business rules]
```

### 3. Value Objects
```yaml
value_objects:
  - name: [ValueObjectName]
    properties:
      - name: [propertyName]
        type: [type]
        validation: [rules]
    used_by: [List of entities using this VO]
```

### 4. Domain Events
```yaml
domain_events:
  - name: [EventName]
    trigger: [What action causes this event]
    properties:
      - name: [propertyName]
        type: [type]
        source: [Where value comes from]
```

### 5. Commands and Business Operations
```yaml
commands:
  - name: [CommandName]
    description: [What this command does]
    parameters:
      - name: [paramName]
        type: [type]
        required: [true/false]
    validations:
      - [Validation rule]
    side_effects:
      - [What happens as result]
    events: [List of events emitted]
```

### 6. Aggregate Relationships
```yaml
relationships:
  - type: [association | composition | aggregation]
    from: [EntityName]
    to: [EntityName]
    cardinality: [1..1 | 1..* | 0..* | etc]
    navigation: [unidirectional | bidirectional]
    cascade: [operations that cascade]
```

## Example: Workflow Aggregate with Lanes

```yaml
aggregate:
  name: Workflow
  description: Represents a workflow board with stages and swimlanes for organizing work items
  bounded_context: Workflow Management
  invariants:
    - A workflow must have at least one stage
    - Stage order must be unique within a workflow
    - Swimlane names must be unique within a workflow

entities:
  root:
    name: Workflow
    id_type: WorkflowId
    properties:
      - name: boardId
        type: String
        description: Reference to the board this workflow belongs to
        constraints: not null
      - name: name
        type: String
        description: Display name of the workflow
        constraints: not blank, max 100 chars
      - name: description
        type: String
        description: Optional description
        constraints: max 500 chars
      - name: lanes
        type: List<Lane>
        description: Collection of stages and swimlanes
        constraints: not empty
    
  children:
    - name: Lane
      parent: Workflow
      id_type: embedded (no separate ID)
      cardinality: one-to-many
      properties:
        - name: laneId
          type: String
          description: Internal identifier within workflow
        - name: type
          type: LaneType (enum: STAGE, SWIMLANE)
          description: Discriminator for lane type
        - name: name
          type: String
          description: Display name
      invariants:
        - Lane IDs must be unique within workflow
      
    - name: Stage
      parent: Lane (inheritance)
      properties:
        - name: order
          type: int
          description: Position in workflow (0-based)
          constraints: >= 0, unique within workflow
        - name: wipLimit
          type: Integer (optional)
          description: Work in progress limit
          constraints: > 0 if present
      invariants:
        - Stages must have sequential order without gaps
        
    - name: Swimlane  
      parent: Lane (inheritance)
      properties:
        - name: order
          type: int
          description: Vertical position (0-based)
          constraints: >= 0, unique within workflow
      invariants:
        - Swimlane names must be unique

value_objects:
  - name: LaneType
    properties:
      - name: value
        type: String enum (STAGE, SWIMLANE)
    used_by: [Lane]
    
  - name: WipLimit
    properties:
      - name: limit
        type: int
        validation: must be positive
    used_by: [Stage]

domain_events:
  - name: WorkflowCreated
    trigger: Create workflow command
    properties:
      - name: workflowId
        type: String
      - name: boardId
        type: String
      - name: name
        type: String
      - name: userId
        type: String
        
  - name: StageAdded
    trigger: Add stage command
    properties:
      - name: workflowId
        type: String
      - name: stageId
        type: String
      - name: name
        type: String
      - name: order
        type: int
        
  - name: SwimlaneAdded
    trigger: Add swimlane command
    properties:
      - name: workflowId
        type: String
      - name: swimlaneId
        type: String
      - name: name
        type: String

commands:
  - name: CreateWorkflow
    description: Creates a new workflow with initial stage
    parameters:
      - name: boardId
        type: String
        required: true
      - name: name
        type: String
        required: true
      - name: firstStageName
        type: String
        required: true
    validations:
      - Board must exist
      - Name must not be blank
    events: [WorkflowCreated, StageAdded]
    
  - name: AddStage
    description: Adds a new stage at specified position
    parameters:
      - name: workflowId
        type: String
        required: true
      - name: name
        type: String
        required: true
      - name: position
        type: int
        required: true
    validations:
      - Workflow must exist
      - Position must be valid (0 to stage count)
      - Name must be unique among stages
    side_effects:
      - Reorder subsequent stages
    events: [StageAdded]
    
  - name: AddSwimlane
    description: Adds a new swimlane
    parameters:
      - name: workflowId
        type: String
        required: true
      - name: name
        type: String
        required: true
    validations:
      - Workflow must exist
      - Name must be unique among swimlanes
    events: [SwimlaneAdded]

relationships:
  - type: composition
    from: Workflow
    to: Lane
    cardinality: 1..*
    navigation: unidirectional
    cascade: [delete, save]
```

## Usage Guidelines

### 1. For Simple Aggregates
Focus on:
- Core properties and constraints
- Key commands and events
- Main invariants

### 2. For Complex Aggregates
Include:
- Full entity hierarchy with inheritance
- Detailed invariants at each level
- Entity relationships and navigation
- State transition rules
- Collection management rules

### 3. Key Information to Provide

**Essential:**
- Aggregate boundaries (what's inside vs outside)
- Entity relationships and cardinality
- Business invariants and rules
- Commands that modify state
- Events that are emitted

**Important:**
- Value objects and their validation
- Entity lifecycle (creation, modification, deletion)
- Ordering and uniqueness constraints
- Reference vs ownership relationships

**Helpful:**
- Example data scenarios
- Edge cases and error conditions
- Performance considerations (e.g., collection sizes)
- Integration points with other aggregates

### 4. Common Patterns for Complex Aggregates

**Hierarchical Entities:**
```yaml
Workflow
  └── Lane (abstract)
      ├── Stage
      └── Swimlane
```

**Ordered Collections:**
```yaml
properties:
  - name: stages
    type: List<Stage>
    constraints: ordered by 'order' property
```

**Polymorphic Entities:**
```yaml
- name: Lane
  discriminator: type
  subtypes: [Stage, Swimlane]
```

**Cross-Entity Invariants:**
```yaml
invariants:
  - "Sum of all stage WIP limits must not exceed workflow limit"
  - "Card can only be in one stage at a time"
```

## Tips for LLM Communication

1. **Start with the Big Picture**: Describe the business purpose before diving into technical details

2. **Use Concrete Examples**: 
   ```
   "A Workflow contains multiple Lanes. A Lane can be either a Stage (horizontal) or Swimlane (vertical). 
   For example: 'To Do', 'In Progress', 'Done' are Stages, while 'Frontend', 'Backend' are Swimlanes."
   ```

3. **Specify Constraints Clearly**:
   ```
   "Stages must maintain sequential order (0, 1, 2...) with no gaps. 
   When a stage is removed, subsequent stages must be reordered."
   ```

4. **Define Business Rules**:
   ```
   "A card can be in exactly one stage and optionally one swimlane at any time."
   ```

5. **Clarify Relationships**:
   ```
   "Workflow OWNS Lanes (composition) - deleting a workflow deletes all its lanes.
   Workflow REFERENCES Board (association) - deleting a board doesn't automatically delete workflows."
   ```