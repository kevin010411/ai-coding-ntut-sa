# ADR-019 - Frontend State Management with RTK Query and Optimistic Updates

## Date
2025-08-18

## Status
Accepted

## Context
在開發 Scrum Board 拖放功能時，我們遇到了多層狀態管理的同步問題：

1. **使用者體驗問題**
   - Task 拖放後會「彈回」原位，然後才移到新位置
   - PBI 狀態更新延遲，需要 reload 才能看到正確狀態
   - UI 閃爍和狀態不一致

2. **技術挑戰**
   - 後端資料庫（真實資料來源）
   - RTK Query 快取層
   - Optimistic Updates（即時 UI 更新）
   - React 元件狀態（UI 渲染）
   - 各層之間的同步問題

3. **之前的問題**
   - 修復 UI 彈回影響快取更新
   - 修復快取更新影響狀態同步
   - 修復狀態同步又影響 UI 體驗
   - 陷入「改 A 錯 B」的循環

## Decision
採用「**Optimistic Update 為主要真相來源**」的系統性解決方案：

### 核心原則
1. **完整性** - Optimistic update 必須完整模擬後端業務邏輯
2. **信任原則** - 成功時信任 optimistic update，不觸發額外 refetch
3. **失敗修正** - 只在失敗時 revert 並重新獲取資料
4. **自然刷新** - 透過組件生命週期自然刷新資料

### 實作策略

#### 1. 完整的 Optimistic Update
```typescript
// 不只更新單一欄位，而是模擬完整的業務邏輯
const patchResult = dispatch(
  pbiApi.util.updateQueryData('getBacklogItemsBySprint', sprintId, (draft) => {
    // 1. 更新 task 狀態
    task.status = newState;
    
    // 2. 根據業務規則更新 PBI 狀態
    if (allTasksDone && pbi.state !== 'DONE') {
      pbi.state = 'DONE';  // PBI 完成
    } else if (!allTasksDone && pbi.state === 'DONE') {
      pbi.state = 'IN_PROGRESS';  // PBI 退回進行中
    }
  })
);
```

#### 2. 成功後不 Invalidate
```typescript
try {
  await queryFulfilled;
  // 成功：信任 optimistic update
  // 不做 invalidateTags，避免觸發不必要的 refetch
} catch (error) {
  // 失敗：revert + invalidate
  patchResult.undo();
  setTimeout(() => {
    dispatch(pbiApi.util.invalidateTags([{ type: 'Sprint', id: sprintId }]));
  }, 100);
}
```

#### 3. 查詢快取配置
```typescript
getBacklogItemsBySprint: builder.query({
  keepUnusedDataFor: 60,           // 保持快取 60 秒
  refetchOnMountOrArgChange: true, // 組件掛載或 reload 時刷新
  refetchOnReconnect: true,         // 網路重連時刷新
  refetchOnFocus: false,            // 避免過度請求
})
```

## Consequences

### Positive
- ✅ 拖放操作即時響應，無彈回現象
- ✅ PBI 狀態立即正確更新並顯示在對應欄位
- ✅ 減少不必要的網路請求
- ✅ UI 流暢無閃爍
- ✅ Reload 後自動獲取最新狀態
- ✅ 避免了「改 A 錯 B」的問題

### Negative
- 前端需要完整理解後端業務邏輯
- Optimistic update 邏輯較複雜
- 需要仔細處理各種邊界情況
- 前後端業務邏輯需要保持同步

### Neutral
- 快取管理策略需要團隊共識
- 需要完整的測試覆蓋
- 需要文檔說明業務規則

## Alternatives Considered

### Option 1: 總是 Invalidate Tags
- **Description**: 每次操作後都 invalidate tags 觸發 refetch
- **Pros**: 資料永遠是最新的，邏輯簡單
- **Cons**: 過多網路請求，UI 閃爍，使用者體驗差
- **Reason for rejection**: 嚴重影響使用者體驗

### Option 2: 不使用 Optimistic Update
- **Description**: 等待伺服器回應後才更新 UI
- **Pros**: 資料永遠正確，不需要 revert 邏輯
- **Cons**: UI 反應慢，拖放體驗差
- **Reason for rejection**: 不符合現代 Web 應用的體驗標準

### Option 3: 使用 Local State + 定期同步
- **Description**: 使用 React local state，定期與後端同步
- **Pros**: UI 反應快速
- **Cons**: 狀態管理複雜，容易不同步，難以處理多使用者場景
- **Reason for rejection**: 增加複雜度且容易出錯

## Related Decisions
- ADR-018: PBI State Transition Invariant Handling（後端配合）
- Frontend API Integration Guide（技術實作指南）

## Notes

### 實作檢查清單
- [ ] Optimistic update 完整模擬業務邏輯
- [ ] 成功時不觸發 invalidate
- [ ] 失敗時正確 revert 和 refetch
- [ ] 查詢設定 `refetchOnMountOrArgChange: true`
- [ ] 適當的快取保留時間
- [ ] 錯誤處理和使用者提示

### 測試重點
1. 單一 task 移動
2. 所有 tasks 移到 DONE（PBI 應變 DONE）
3. Task 從 DONE 移回（PBI 應變 IN_PROGRESS）
4. 網路失敗時的 revert
5. 頁面 reload 後的狀態

### 團隊共識
- 前端開發者需要理解相關的業務規則
- 業務規則變更時需要同步更新前後端
- Code Review 時特別注意 optimistic update 的完整性

### 參考資源
- [RTK Query - Optimistic Updates](https://redux-toolkit.js.org/rtk-query/usage/optimistic-updates)
- [RTK Query - Cache Behavior](https://redux-toolkit.js.org/rtk-query/usage/cache-behavior)
- 專案文件：`.ai/tech-stacks/frontend-react-typescript/api-integration-guide.md`