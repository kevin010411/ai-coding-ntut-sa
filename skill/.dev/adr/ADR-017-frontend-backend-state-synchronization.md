# ADR-017: 前端後端狀態同步架構決策

## 狀態
已接受 (Accepted)

## 日期
2025-08-17

## 背景
在 Scrum Board 功能開發過程中，遇到以下狀態管理挑戰：

1. **PBI 狀態機問題**：PBI 有四個狀態（BACKLOGGED → SELECTED → IN_PROGRESS → DONE），但狀態轉換邏輯分散在前後端
2. **Sprint 狀態依賴**：Task 只能在 Sprint 開始後才能移動，需要前端感知 Sprint 狀態
3. **RTK Query 快取同步**：多次修復快取問題，從手動 refetch 到 optimistic updates
4. **事件驅動不完整**：SprintStarted 事件未觸發 PBI 狀態更新

## 決策

### 1. PBI 狀態機管理原則
**後端為唯一狀態源 (Single Source of Truth)**
- 所有狀態轉換邏輯集中在後端 Domain Entity
- 前端只負責顯示和觸發狀態變更請求
- 狀態轉換規則由 Domain Events 驅動

### 2. Sprint 與 PBI 狀態同步策略
採用**事件驅動 + 防禦性編程**雙重保障：

#### 主要機制：事件驅動
- SprintStarted 事件觸發所有 SELECTED PBI 轉為 IN_PROGRESS
- SprintCompleted 事件處理未完成的 PBI
- 使用 Event Handler 監聽並處理狀態變更

#### 防禦機制：狀態檢查
- moveTask 方法增加 SELECTED → IN_PROGRESS 自動轉換
- 確保即使事件處理失敗，業務邏輯仍能正確執行

### 3. 前端狀態管理策略
**RTK Query Optimistic Updates + Selective Invalidation**

```javascript
// Optimistic update 策略
moveTask: builder.mutation({
  async onQueryStarted({ sprintId, pbiId, taskId, newState }, { dispatch, queryFulfilled }) {
    // 1. 立即更新本地快取
    const patchResult = dispatch(
      pbiApi.util.updateQueryData('getBacklogItemsBySprint', sprintId, (draft) => {
        // 更新邏輯
      })
    );
    
    try {
      await queryFulfilled;
      // 2. 成功：保留 optimistic update
    } catch {
      // 3. 失敗：回滾並重新獲取
      patchResult.undo();
      dispatch(pbiApi.util.invalidateTags([...]));
    }
  },
  // 4. 不自動 invalidate，避免覆蓋 optimistic update
  invalidatesTags: () => [],
})
```

### 4. 前端 Sprint 狀態感知
- 顯示 Sprint 狀態警告訊息
- 提供「開始 Sprint」按鈕
- Sprint 未開始時禁用拖放功能
- 清楚告知使用者當前限制

## 實作細節

### 後端防禦性編程
```java
// ProductBacklogItem.java
public void moveTask(TaskId taskId, ScrumBoardTaskState newState, String movedBy) {
    // ... 前置檢查 ...
    
    // 防禦機制：自動處理 SELECTED → IN_PROGRESS
    if (this.state == PbiState.SELECTED && 
        fromState == ScrumBoardTaskState.TODO && 
        newState != ScrumBoardTaskState.TODO) {
        apply(new PbiBecameInProgress(...));
    }
    
    // 主要邏輯：移動 Task
    apply(new TaskMoved(...));
    
    // 檢查 PBI 完成狀態
    if (this.state == PbiState.IN_PROGRESS && allTasksDone()) {
        apply(new PbiCompleted(...));
    }
}
```

### 前端狀態映射
```typescript
// PBI 狀態映射到簡化的前端狀態
const mapPbiState = (backendState: string) => {
  switch(backendState) {
    case 'BACKLOGGED':
    case 'SELECTED':
    case 'IN_PROGRESS':
      return 'TODO';
    case 'DONE':
      return 'DONE';
  }
};
```

### Sprint Started Event Handler
```java
@EventHandler
public class SprintEventHandler {
    public void handle(SprintStarted event) {
        // 查詢該 Sprint 的所有 SELECTED PBI
        List<ProductBacklogItem> selectedPbis = 
            pbiRepository.findBySprintIdAndState(event.getSprintId(), PbiState.SELECTED);
        
        // 批次更新狀態
        for (ProductBacklogItem pbi : selectedPbis) {
            pbi.startSprint(event.getSprintId(), event.getStartedBy());
            pbiRepository.save(pbi);
        }
    }
}
```

## 決策理由

1. **明確職責分離**：後端管理業務邏輯，前端專注顯示
2. **雙重保障**：事件驅動為主，防禦編程為輔
3. **使用者體驗優先**：Optimistic updates 提供即時回饋
4. **容錯性**：即使某個機制失敗，系統仍能正常運作

## 後果

### 正面影響
- ✅ 狀態管理邏輯集中，易於維護
- ✅ 使用者體驗流暢（optimistic updates）
- ✅ 系統容錯性高（雙重保障）
- ✅ 前後端職責明確

### 負面影響
- ⚠️ 需要實作 Event Handler（增加複雜度）
- ⚠️ 防禦性編程可能導致重複邏輯
- ⚠️ 前端需要理解後端狀態機

### 風險緩解
- 使用整合測試確保事件處理正確
- 記錄詳細的狀態轉換日誌
- 前端增加錯誤處理和重試機制

## 相關 ADR
- ADR-012: Task Moved Event Design - 定義了 TaskMoved 事件結構
- ADR-015: RTK Query 快取策略 - 初始快取策略（已優化）
- ADR-016: RTK Query 最佳實踐 - 現行快取管理方案

## 檢查清單
- [ ] 實作 SprintStarted event handler
- [ ] ProductBacklogItem.moveTask 增加防禦機制
- [ ] 前端實作 Sprint 狀態檢查
- [ ] 整合測試覆蓋狀態轉換場景
- [ ] 監控日誌確認事件處理正確

## 替代方案（已否決）

### 方案 A：純前端狀態管理
- ❌ 違反 Single Source of Truth
- ❌ 容易造成前後端狀態不一致

### 方案 B：同步 API 呼叫
- ❌ 每次操作都重新獲取所有資料
- ❌ 效能差，使用者體驗不佳

### 方案 C：WebSocket 即時同步
- ❌ 過度設計，增加系統複雜度
- ❌ 對現有架構改動太大

## 修訂歷史
- 2025-08-17：初始決策，解決 PBI 狀態同步問題