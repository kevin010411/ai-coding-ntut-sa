# ADR-018 - PBI State Transition Invariant Handling

## Date
2025-08-18

## Status
Accepted

## Context
在 Event Sourcing 架構中，當 PBI (Product Backlog Item) 的 task 狀態改變、被創建或被刪除時，可能會觸發 PBI 本身的狀態轉換。例如：
- 當所有 tasks 都變成 DONE 時，PBI 應該變成 DONE
- 當 PBI 在 DONE 狀態，但有 task 從 DONE 移回其他狀態時，PBI 應該退回 IN_PROGRESS
- 當刪除 task 後，如果剩餘的所有 tasks 都是 DONE，PBI 應該變成 DONE
- 當 PBI 在 DONE 狀態時創建新 task，PBI 應該退回 IN_PROGRESS

這個過程涉及多個事件的產生和應用：
1. `TaskCreated` 事件 - 創建新 task
2. `TaskMoved` 事件 - 更新 task 狀態
3. `TaskDeleted` 事件 - 刪除 task
4. `PbiCompleted` 事件 - 更新 PBI 狀態（從 IN_PROGRESS 變成 DONE）
5. `PbiWorkRegressed` 事件 - 更新 PBI 狀態（從 DONE 退回 IN_PROGRESS）

問題是：在這些事件之間存在臨時的不一致狀態，此時 PBI 狀態可能與 tasks 狀態不同步。這違反了業務 invariant：「當 PBI 是 DONE 時，所有 tasks 必須是 DONE」。

前端也有相關問題：RTK Query 的 optimistic updates 在成功後被立即 invalidate，導致 UI 閃爍和狀態回彈。

## Decision
1. **後端**：允許在事件處理過程中存在臨時的不一致狀態，並在 invariant 檢查邏輯中特別處理這種情況：
```java
// 當 PBI 是 DONE 但不是所有 tasks 都是 DONE 時
if (state == PbiState.DONE && !allTasksDone()) {
    // 這是臨時狀態 - task 已移動但 PBI 狀態尚未更新
    // PbiWorkRegressed 事件會修正這個狀態
    // 所以不強制執行 invariant
}
```

2. **前端**：修改 RTK Query 的 cache 更新策略，避免在 optimistic update 成功後立即 invalidate：
- 移除 `expandedPbis` 從 `useMemo` 的依賴項
- 直接在渲染時檢查展開狀態

## Consequences

### Positive
- 允許正常的 PBI 狀態回退流程執行
- 保持 Event Sourcing 的事件順序性
- 維持系統的最終一致性
- 不影響其他正常的 invariant 檢查
- 前端 UI 更加流暢，沒有閃爍或狀態回彈

### Negative
- invariant 檢查邏輯變得更複雜
- 需要理解事件處理的時序關係
- 可能需要在其他類似場景中採用相同策略

### Neutral
- 需要文檔說明這種臨時不一致是設計上允許的
- 測試案例需要覆蓋這些臨時狀態

## Alternatives Considered

### Option 1: 嚴格執行 Invariant
- **Description**: 不允許任何臨時不一致，在 invariant 檢查時拋出異常
- **Pros**: 邏輯簡單清晰，符合 DDD 的嚴格 invariant 原則
- **Cons**: 會導致正常的狀態轉換失敗
- **Reason for rejection**: 無法支援必要的業務流程

### Option 2: 延遲 Invariant 檢查
- **Description**: 將 invariant 檢查延遲到所有事件都應用完成後
- **Pros**: 避免臨時狀態的問題
- **Cons**: 需要大幅修改 ezddd 框架的事件處理機制
- **Reason for rejection**: 改動過大，影響範圍太廣

### Option 3: 合併事件
- **Description**: 將 TaskMoved 和 PbiWorkRegressed 合併為單一事件
- **Pros**: 沒有臨時狀態問題
- **Cons**: 違反單一職責原則，事件語義不清
- **Reason for rejection**: 降低事件的可讀性和可維護性

## Related Decisions
- ADR-001: UseCase Package Structure
- ADR-004: Sub-agent Architecture Decision
- ADR-009: Command/Query Sub-agent Separation

## Notes
### Implementation Details
1. invariant 檢查應該能識別臨時狀態：
   - 檢查當前聚合狀態
   - 判斷是否處於已知的臨時不一致模式
   - 對臨時狀態跳過特定的 invariant 檢查

2. 確保事件產生的順序：
   - TaskCreated/TaskMoved/TaskDeleted 事件必須先產生
   - 根據新狀態判斷是否需要 PBI 狀態轉換
   - 在同一個方法調用中產生所有必要的事件

3. PBI 狀態轉換規則：
   - **移動 task 到 DONE**：如果所有 tasks 都 DONE → PBI 變成 DONE
   - **移動 task 從 DONE**：如果 PBI 是 DONE → PBI 退回 IN_PROGRESS
   - **刪除 task**：如果剩餘的所有 tasks 都 DONE → PBI 變成 DONE
   - **創建 task**：如果 PBI 是 DONE → PBI 退回 IN_PROGRESS（新工作加入）

4. 測試覆蓋：
   - 單元測試驗證事件產生順序
   - 整合測試確認 API 返回正確的最終狀態
   - 確保沒有遺漏的狀態轉換場景
   - 測試刪除 task 後的 PBI 狀態轉換

### References
- Event Sourcing Pattern: https://martinfowler.com/eaaDev/EventSourcing.html
- DDD Aggregate Invariants: https://enterprisecraftsmanship.com/posts/domain-model-purity-lazy-loading/
- 相關程式碼: `ProductBacklogItem.java` 的 `moveTask()` 和 `ensureInvariant()` 方法
- 相關前端程式碼: `ScrumBoardWithSwimlanes.tsx` 和 `pbiApi.ts`