# ADR-012: Task Moved Event Design - Single Event with State Enum

## Status
Accepted

## Context
在實作 Scrum Board 的 Task 狀態變更功能時，需要設計 Domain Event 來記錄 Task 在看板上的移動。我們面臨兩種設計選擇：

1. **細分事件方式**：為每個狀態轉換創建獨立事件
   - TaskMovedToDoing
   - TaskMovedToTesting
   - TaskMovedToReview
   - TaskMovedToDone
   - TaskMovedToTodo

2. **單一事件方式**：使用一個 TaskMoved 事件，搭配 ScrumBoardTaskState Enum

## Decision
我們決定採用**單一 TaskMoved 事件搭配 ScrumBoardTaskState Enum** 的設計方式。

### Event 結構設計
```java
public class TaskMoved extends DomainEvent {
    private String taskId;
    private String productBacklogItemId;
    private String sprintId;
    private ScrumBoardTaskState fromState;
    private ScrumBoardTaskState toState;
    private String movedBy;
    private Instant occurredAt;
}
```

## Rationale

### 選擇單一事件的原因

1. **簡潔性與維護性**
   - 只需維護一個事件類別，減少程式碼重複
   - 新增狀態時只需擴充 Enum，不需創建新事件類別
   - 降低測試複雜度

2. **彈性與擴展性**
   - 支援動態看板欄位配置（如可選的 TEST、REVIEW 欄位）
   - 容易適應未來的狀態變更需求
   - 便於實作狀態轉換規則驗證

3. **完整的上下文資訊**
   - 包含 fromState 和 toState，提供完整的狀態轉換脈絡
   - 便於追蹤和審計狀態變化歷程
   - 支援複雜的業務規則（如禁止某些狀態轉換）

4. **符合 DDD 原則**
   - 事件名稱反映實際的業務行為（Task 被移動）
   - 狀態是事件的屬性，而非行為本身
   - 更貼近 Ubiquitous Language

5. **Event Sourcing 友好**
   - 單一事件類型簡化事件流的重建邏輯
   - 便於實作狀態機和狀態驗證
   - 減少事件版本管理的複雜度

### 細分事件的缺點

- **類別爆炸**：需要 5+ 個事件類別，增加維護成本
- **重複邏輯**：每個事件的處理邏輯相似，造成程式碼重複
- **訂閱複雜**：Event Handler 需要訂閱多個事件類型
- **擴展困難**：新增狀態需要創建新的事件類別和處理器

## Consequences

### Positive
- ✅ 程式碼更簡潔，易於理解和維護
- ✅ 彈性支援看板欄位的動態配置
- ✅ 提供完整的狀態轉換上下文
- ✅ 便於實作業務規則和狀態驗證
- ✅ 簡化事件訂閱和處理邏輯
- ✅ 減少測試案例數量

### Negative
- ⚠️ Event Handler 需要使用 switch/if 判斷具體狀態
- ⚠️ 可能需要額外的輔助方法來判斷特定的狀態轉換

### Neutral
- 需要在 Event Handler 中實作狀態判斷邏輯
- 可透過輔助方法（如 isMovedToComplete()）改善可讀性

## Implementation Notes

### 輔助方法範例
```java
public class TaskMoved extends DomainEvent {
    // ... properties ...
    
    public boolean isTaskStarted() {
        return fromState == ScrumBoardTaskState.TODO 
            && toState == ScrumBoardTaskState.DOING;
    }
    
    public boolean isTaskCompleted() {
        return toState == ScrumBoardTaskState.DONE;
    }
    
    public boolean isMovedBackward() {
        return toState.ordinal() < fromState.ordinal();
    }
}
```

### Event Handler 範例
```java
@EventHandler
public void handle(TaskMoved event) {
    // 記錄狀態轉換
    logger.info("Task {} moved from {} to {}", 
        event.getTaskId(), 
        event.getFromState(), 
        event.getToState());
    
    // 根據目標狀態執行特定邏輯
    switch (event.getToState()) {
        case DOING:
            handleTaskStarted(event);
            break;
        case DONE:
            handleTaskCompleted(event);
            updateSprintProgress(event);
            break;
        case TODO:
            handleTaskReopened(event);
            break;
        default:
            // 其他狀態的處理
    }
}
```

## Related Decisions
- ADR-011: Sprint Board Configuration Dynamic Columns
- ADR-009: Command/Query Sub-agent 分離

## References
- Domain-Driven Design by Eric Evans
- Implementing Domain-Driven Design by Vaughn Vernon
- Event Sourcing Pattern: https://martinfowler.com/eaaDev/EventSourcing.html

## Record
- Date: 2025-01-17
- Author: AI Assistant (Claude)
- Approved by: Development Team