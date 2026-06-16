# ADR-008 - UI Development Timing Decision

## Date
2025-08-15

## Status
Accepted

## Context
The AiScrum project has reached a point where we need to decide whether to:
1. Start UI development with the current backend implementation
2. Continue backend development to provide more complete functionality

### Current Implementation Status

**Implemented Features (100 production files, 52 test files):**
- **Product Management**: Create, Get, Set Goal, Define DoD (✅ Basic Complete)
- **PBI Management**: Create, Estimate, Select/Unselect, Task CRUD operations (✅ Basic Complete)
- **Sprint Management**: Create, Set Timebox, Define Goal (⚠️ Partially Complete)
- **REST APIs**: 13 Controllers with 202 Accepted async patterns

**Missing Critical Features:**
- **Query Operations**: Most Read/List operations for displaying data
- **Sprint Lifecycle**: Start/End Sprint, Sprint state transitions
- **Task Workflow**: Status updates (To Do → In Progress → Done)
- **User Management**: Authentication, authorization, team management
- **Metrics**: Burndown charts, velocity, progress tracking

### Key Considerations
1. **UI Data Requirements**: UI needs Query APIs to display meaningful information
2. **User Experience**: Without core workflows, UI would be severely limited
3. **Development Efficiency**: Building UI without stable backend APIs leads to rework
4. **Resource Allocation**: Single developer vs team considerations
5. **MVP Definition**: What constitutes a minimal viable Scrum tool

## Decision
**Continue backend development before starting UI implementation**

### Development Roadmap

#### Phase 1: Core Query Operations (1-2 weeks)
Priority: **MUST HAVE** for any UI
```
- GetSprintUseCase & Controller
- ListProductBacklogItemsUseCase & Controller  
- GetSprintBacklogUseCase & Controller
- ListTasksByPbiUseCase & Controller
- ListProductsUseCase & Controller
```

#### Phase 2: Sprint Lifecycle (1 week)
Priority: **MUST HAVE** for Scrum workflow
```
- StartSprintUseCase & Controller
- EndSprintUseCase & Controller
- UpdateTaskStatusUseCase & Controller
- GetSprintProgressUseCase & Controller
```

#### Phase 3: Basic User System (1 week)
Priority: **SHOULD HAVE** for production
```
- CreateUserUseCase
- AuthenticateUserUseCase
- JWT implementation (replace current stub)
- Team management basics
```

#### Phase 4: UI Development Start
With Phases 1-2 complete, begin UI development with:
- Product list and management
- Product Backlog view
- Sprint Planning board
- Sprint Board (Kanban/Scrum board)
- Basic Sprint metrics

### Alternative Approach (if team available)
**Parallel Development Strategy:**
- **Backend Team**: Continue with Phases 1-3
- **Frontend Team**: 
  - Set up UI framework and architecture
  - Create UI components with mock data
  - Implement UI routing and state management
  - Prepare for API integration

## Consequences

### Positive
- ✅ **Stable API Foundation**: UI built on complete, tested APIs
- ✅ **Better UX**: Full workflow implementation enables meaningful user interactions
- ✅ **Reduced Rework**: Avoid changing UI when backend APIs change
- ✅ **Clear MVP**: Complete Scrum cycle functionality
- ✅ **Proper Testing**: Backend fully tested before UI integration

### Negative
- ⚠️ **Delayed Visual Progress**: Stakeholders wait longer to see UI
- ⚠️ **Later User Feedback**: UI/UX feedback comes later in development
- ⚠️ **Sequential Development**: Potentially longer total development time

### Neutral
- 📝 UI mockups/prototypes can be created independently
- 📝 Backend APIs can be documented with OpenAPI/Swagger for UI team reference
- 📝 Mock data structures can be shared between teams

## Alternatives Considered

### Option 1: Start UI Development Immediately
- **Pros**: 
  - Early visual progress
  - Early user feedback
  - Parallel workstreams possible
- **Cons**: 
  - Limited functionality (display-only)
  - High rework probability
  - Poor user experience with incomplete workflows
- **Reason for rejection**: Missing Query APIs make meaningful UI impossible

### Option 2: Minimal Backend + UI
- **Description**: Implement only Query APIs, start UI, then iterate
- **Pros**: 
  - Faster initial UI
  - Iterative development
- **Cons**: 
  - Incomplete workflows frustrate users
  - Constant context switching
  - Integration complexity
- **Reason for rejection**: Poor user experience with half-implemented features

### Option 3: Full Backend First
- **Description**: Complete ALL backend features before any UI
- **Pros**: 
  - Complete API surface
  - No UI rework needed
- **Cons**: 
  - Very late user feedback
  - Risk of building unused features
  - Long time without visible progress
- **Reason for rejection**: Too risky, lacks iterative feedback

## Implementation Guidelines

### Minimum APIs Required for UI Start
```yaml
Products:
  - GET /v1/api/products (list)
  - GET /v1/api/products/{id} (existing)
  
Product Backlog:
  - GET /v1/api/products/{id}/pbis (list)
  - GET /v1/api/pbis/{id} (detail)
  
Sprints:
  - GET /v1/api/products/{id}/sprints (list)
  - GET /v1/api/sprints/{id} (detail)
  - GET /v1/api/sprints/{id}/backlog (sprint backlog)
  - POST /v1/api/sprints/{id}/start
  - POST /v1/api/sprints/{id}/end
  
Tasks:
  - GET /v1/api/pbis/{id}/tasks (list)
  - PATCH /v1/api/tasks/{id}/status (update)
```

### Success Criteria
Before starting UI development, ensure:
1. ✅ All Phase 1 Query APIs implemented and tested
2. ✅ Phase 2 Sprint lifecycle complete
3. ✅ API documentation (OpenAPI/Swagger) available
4. ✅ Integration tests passing for complete workflows
5. ✅ At least one complete user journey possible (Create Product → Create PBIs → Plan Sprint → Execute Sprint)

## Related Decisions
- [ADR-001](./ADR-001-usecase-package-structure.md) - UseCase package structure
- [ADR-006](./ADR-006-rest-api-path-design.md) - REST API path design
- Future: ADR-009 - UI Technology Stack Selection (React/Vue/Angular)
- Future: ADR-010 - API Documentation Strategy

## Notes
### Quick Win Opportunities
If stakeholder pressure for UI exists, consider:
1. **API Documentation UI**: Generate Swagger UI for API testing
2. **Admin Dashboard**: Simple metrics dashboard using existing data
3. **Figma/Mockups**: Create detailed UI mockups for stakeholder review

### Risk Mitigation
- Create OpenAPI specs for all planned APIs before implementation
- Share data models/DTOs with potential UI developers early
- Consider GraphQL for future UI flexibility (separate ADR needed)

### Review Date
Review this decision after Phase 1 completion (approximately 2 weeks) to assess if approach needs adjustment based on:
- Development velocity
- Stakeholder feedback
- Resource availability changes

---

**Decision made by**: Development Team  
**Stakeholders consulted**: Product Owner, Scrum Master, Technical Lead  
**Review scheduled**: 2025-09-01


My Recommendation: Continue Backend Development 🚀

理由：

1. 缺少核心查詢功能 - 你有很多 Create/Update 操作，但缺少對應的 Query/Read 操作。UI 需要這些來顯示資料。
2. Sprint 生命週期不完整 - Sprint 的開始、進行中、結束流程還沒實作，這是 Scrum 的核心。
3. 沒有用戶系統 - 目前所有操作都用 stub 的 "user-123"，需要真實的用戶管理。
4. 缺少關鍵的狀態轉換 - Task 狀態變更、Sprint 狀態變更等核心工作流程。

建議的開發優先順序：

Phase 1: 完成核心查詢功能 (1-2 週)

- GetSprintUseCase (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/sprint/usecase/get-sprint.json use case spec. It is a query returns a GetSprintOutput<List<SrpintDto>> by SprintId, reference the .dev/specs/product/usecase/get-product.json as a template.
  [] 2. Write .dev/tasks/feature/sprint/usecase/task-get-sprint.json to execute the .dev/specs/sprint/usecase/get-sprint.json
  [] 3. Execute .dev/tasks/feature/sprint/usecase/task-get-sprint.json
  [] 4. Write .dev/specs/sprint/adapter/get-sprint-controller.json controller spec. It is a rest controller of GetSprintUseCase to return a SprintDto.  
  [] 5. Write .dev/tasks/feature/sprint/adapter/task-get-sprint-controller.json to execute the .dev/specs/sprint/adapter/get-sprint-controller.json
  [] 6. Execute .dev/tasks/feature/sprint/adapter/task-get-sprint-controller.json

- GetSprintsByProductUseCase (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/sprint/usecase/get-sprints-by-product.json use case spec. It is a query returns a GetSprintsByProductOutput<List<SrpintDto>> by ProductId, reference the .dev/specs/product/usecase/get-product.json as a template.
  [] 2. Write .dev/tasks/feature/sprint/usecase/task-get-sprints-by-product.json to execute the .dev/specs/sprint/usecase/get-sprints-by-product.json
  [] 3. Execute .dev/tasks/feature/sprint/usecase/task-get-sprints-by-product.json
  [] 4. Write .dev/specs/sprint/adapter/get-sprints-by-product-controller.json controller spec. It is a rest controller of GetSprintsByProductUseCase to return a list of SprintDto.  
  [] 5. Write .dev/tasks/feature/sprint/adapter/task-get-sprints-by-product-controller.json to execute the .dev/specs/sprint/adapter/get-sprints-by-product-controller.json
  [] 6. Execute .dev/tasks/feature/sprint/adapter/task-get-sprints-by-product-controller.json


- GetBacklogItemsByProductUseCase (Done)

Execute the following tasks:
[]  1. Write .dev/specs/pbi/usecase/get-pbis-by-product.json use case spec. It is a query returns a GetBacklogItemsByProductOutput<List<ProductBacklogItemDto>> by ProductId, reference the .dev/specs/product/usecase/get-product.json as a template.
[]  2. Write .dev/tasks/feature/pbi/usecase/task-get-pbis-by-product.json to execute the '.dev/specs/pbi/usecase/get-pbis-by-product.json'
[]  3. Execute .dev/tasks/feature/pbi/usecase/task-get-pbis-by-product.json
[]  4. Write .dev/specs/pbi/adapter/get-pbis-by-product-controller.json controller spec. It is a rest controller of GetBacklogItemsByProductUseCase to return a list of ProductBacklogItemDto.  
[]  5. Write .dev/tasks/feature/pbi/adapter/task-get-pbis-by-product-controller.json to execute the .dev/specs/pbi/adapter/get-pbis-by-product-controller.json
[]  6. Execute .dev/tasks/feature/pbi/adapter/task-get-pbis-by-product-controller.json


- GetBacklogItemsBySprintUseCase (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/pbi/usecase/get-pbis-by-sprint.json use case spec. It is a query returns a GetBacklogItemsBySprintOutput<List<ProductBacklogItemDto>> by SprintId, reference the .dev/specs/product/usecase/get-product.json as a template.
  [] 2. Write .dev/tasks/feature/pbi/usecase/task-get-pbis-by-sprint.json to execute the .dev/specs/pbi/usecase/get-pbis-by-sprint.json
  [] 3. Execute .dev/tasks/feature/pbi/usecase/task-get-pbis-by-sprint.json
  [] 4. Write .dev/specs/pbi/adapter/get-pbis-by-sprint-controller.json controller spec. It is a rest controller of GetBacklogItemsBySprintUseCase to return a list of ProductBacklogItemDto.  
  [] 5. Write .dev/tasks/feature/pbi/adapter/task-get-pbis-by-sprint-controller.json to execute the .dev/specs/pbi/adapter/get-pbis-by-sprint-controller.json
  [] 6. Execute .dev/tasks/feature/pbi/adapter/task-get-pbis-by-sprint-controller.json


- GetTasksByProductBacklogItemUseCase (Done)
  In the .dev/specs/pbi/usecase folder, write 'get-tasks-by-pbi.json' use case spec. It is a query returns all Tasks as List<TaskDto> by ProductBacklogItemId, reference the .dev/specs/product/usecase/get-product.json as a template.
  In the .dev/specs/pbi/adapter folder, write 'get-tasks-by-pbi-controller.json' controller spec. It is a rest controller of GetTasksByProductBacklogItemUseCase to return a list of TaskDto. 


- GetProductsUseCase (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/product/usecase/get-products.json use case spec. It is a query returns a GetProductsOutput<List<ProductDto>>, reference the .dev/specs/product/usecase/get-product.json as a template.
  [] 2. Write .dev/tasks/feature/product/usecase/task-get-products.json to execute the .dev/specs/product/usecase/get-products.json
  [] 3. Execute .dev/tasks/feature/product/usecase/task-get-products.json
  [] 4. Write .dev/specs/product/adapter/get-products-controller.json controller spec. It is a rest controller of GetProductsUseCase to return a list of ProductsDto.  
  [] 5. Write .dev/tasks/feature/product/adapter/task-get-products-controller.json to execute the .dev/specs/product/adapter/get-products-controller.json
  [] 6. Execute .dev/tasks/feature/product/adapter/task-get-products-controller.json


- SetTaskStatus (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/pbi/usecase/set-task-status.json use case spec. It is a SetTaskStatusUseCase accepting a productId, pbiId, taskId, and taskState (all of them are String type) as input to set a task's status; reference the .dev/specs/pbi/usecase/estimate-task.json as a template.
  [] 2. Write .dev/tasks/feature/pbi/usecase/task-set-task-status.json to execute the .dev/specs/pbi/usecase/set-task-status.json
  [] 3. Execute .dev/tasks/feature/pbi/usecase/task-set-task-status.json
  [] 4. Write .dev/specs/pbi/adapter/set-task-status-controller.json controller spec. It is a rest controller of SetTaskStatusUseCase.  
  [] 5. Write .dev/tasks/feature/pbi/adapter/task-set-task-status-controller.json to execute the .dev/specs/pbi/adapter/set-task-status-controller.json
  [] 6. Execute .dev/tasks/feature/pbi/adapter/task-set-task-status-controller.json


- StartSprint (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/sprint/usecase/start-sprint.json use case spec. It is a StartSprintUseCase accepting a productId, sprintId, and an occurredOn (i.e, an optional input, if it is presented, use the input.occurredOn to set the occurredOn of a SpartStarted domain event) as input to set a Sprint's status; reference the .dev/specs/pbi/usecase/estimate-task.json as a template.
  [] 2. Write .dev/tasks/feature/sprint/usecase/task-start-sprint.json to execute .dev/specs/sprint/usecase/start-sprint.json
  [] 3. Execute .dev/tasks/feature/sprint/usecase/task-start-sprint.json
  [] 4. Write .dev/specs/sprint/adapter/start-sprint-controller.json controller spec. It is a rest controller of StartSprintUseCase.  
  [] 5. Write .dev/tasks/feature/sprint/adapter/task-start-sprint-controller.json to execute the .dev/specs/sprint/adapter/start-sprint-controller.json
  [] 6. Execute .dev/tasks/feature/sprint/adapter/task-start-sprint-controller.json

- CompleteSprint (Done)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/sprint/usecase/complete-sprint.json use case spec. It is a CompleteSprintUseCase accepting a productId, sprintId, and an occurredOn (i.e, an optional input, if it is presented, use the input.occurredOn to set the occurredOn of a SpartCompleted domain event) as input to set a Sprint's status; reference the .dev/specs/pbi/usecase/estimate-task.json as a template.
  [] 2. Write .dev/tasks/feature/sprint/usecase/task-complete-sprint.json to execute .dev/specs/sprint/usecase/complete-sprint.json
  [] 3. Execute .dev/tasks/feature/sprint/usecase/task-complete-sprint.json
  [] 4. Write .dev/specs/sprint/adapter/complete-sprint-controller.json controller spec. It is a rest controller of CompleteSprintUseCase.  
  [] 5. Write .dev/tasks/feature/sprint/adapter/task-complete-sprint-controller.json to execute the .dev/specs/sprint/adapter/complete-sprint-controller.json
  [] 6. Execute .dev/tasks/feature/sprint/adapter/task-complete-sprint-controller.json


- CancelSprint (Doing)

  Execute the following tasks step by step:
  [] 1. Write .dev/specs/sprint/usecase/cancel-sprint.json use case spec. It is a CancelSprintUseCase accepting a productId, sprintId, a reason, and an occurredOn (i.e, an optional input, if it is presented, use the input.occurredOn to set the occurredOn of a SpartCanceled domain event) as input to set a Sprint's status; reference the .dev/specs/sprint/usecase/complete-sprint.json as a template.
  [] 2. Write .dev/tasks/feature/sprint/usecase/task-cancel-sprint.json to execute .dev/specs/sprint/usecase/cancel-sprint.json
  [] 3. Execute .dev/tasks/feature/sprint/usecase/task-cancel-sprint.json
  [] 4. Write .dev/specs/sprint/adapter/cancel-sprint-controller.json controller spec. It is a rest controller of CancelSprintUseCase.  
  [] 5. Write .dev/tasks/feature/sprint/adapter/task-cancel-sprint-controller.json to execute the .dev/specs/sprint/adapter/cancel-sprint-controller.json
  [] 6. Execute .dev/tasks/feature/sprint/adapter/task-cancel-sprint-controller.json

public enum SprintState {
PLANNED,
STARTED,
COMPLETED,
CANCELLED
}



Phase 2: Sprint 生命週期 (1 週)
- StartSprintUseCase
- EndSprintUseCase
- UpdateTaskStatusUseCase


Phase 3: 基礎用戶系統 (1 週)
- CreateUserUseCase
- AuthenticateUserUseCase
- Simple JWT implementation

Then: Start UI Development
有了這些基礎後，你就有足夠的 API 來支撐一個有意義的 UI。

Alternative: Parallel Development

如果你有團隊資源，可以考慮：
- Backend Team: 繼續完成上述功能
- Frontend Team: 開始建立基礎 UI 架構，使用 mock data

如果你現在就想開始 UI：

至少先實作這些查詢 API：
1. GET /v1/api/products - List all products
2. GET /v1/api/products/{id}/pbis - Get PBIs for a product
3. GET /v1/api/sprints/{id} - Get sprint details
4. GET /v1/api/pbis/{id}/tasks - Get tasks for a PBI

這樣 UI 才有基本的資料可以顯示。

你的想法呢？ 是想繼續完善後端，還是想並行開發 UI？
==

⏺ 根據 ADR-008 的分析，我強烈建議你先不要開始實作前端 UI。

🛑 為什麼現在不適合？

你的後端缺少關鍵的查詢功能：
- 沒有列表功能（List Products, List PBIs, List Tasks）
- 沒有詳細查詢（Get Sprint, Get PBI details）
- Sprint 生命週期不完整（Start/End Sprint）
- Task 狀態管理缺失（To Do → In Progress → Done）

UI 沒有這些 API 就像無米之炊 - 你只能顯示靜態頁面，無法展示任何有意義的資料。

✅ 建議的行動方案

選項 1：先完成核心查詢 API（推薦）

花 1-2 週實作 Phase 1 的查詢功能，至少包括：
- GetSprintUseCase
- GetBacklogItemsByProductUseCase
- GetBacklogItemsBySprintUseCase
- GetTasksByProductBacklogItemUseCase
- ListProductsUseCase

選項 2：並行開發（如果你有前端資源）

- 後端：繼續實作查詢 API
- 前端：搭建 UI 框架、設計組件、使用 mock data 開發

選項 3：最小可行方案

如果你真的想現在就看到 UI，至少先實作這 4 個 API：
GET /v1/api/products
GET /v1/api/products/{id}/pbis
GET /v1/api/sprints/{id}
GET /v1/api/pbis/{id}/tasks

💡 我的建議

再忍耐 1-2 週，先把查詢 API 做完。現在開始 UI 會讓你：
- 不斷修改前端程式碼
- 用戶體驗極差（只能創建，看不到資料）
- 浪費時間在 mock data 上

