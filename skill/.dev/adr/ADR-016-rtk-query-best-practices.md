# ADR-016: RTK Query 最佳實踐與快取管理

## 狀態
已接受 (Accepted)

## 日期
2025-08-17

## 背景
經過多次快取問題（尤其是 Scrum Board 顯示舊資料），我們發現之前的解決方案都是補丁式的：
- 使用 `setTimeout` 延遲重新獲取
- 手動調用 `refetch()`
- 設定 `keepUnusedDataFor: 0`
- 在多個地方添加 `refetchOnMount`

這些方法都沒有從根本上解決問題，導致問題反覆出現。

## 決策
採用 RTK Query 的標準最佳實踐，建立正確的快取管理機制。

### 核心原則
1. **正確的 Tag 系統**：每個資源都有對應的 tag，確保快取失效精準
2. **Optimistic Updates**：在 mutation 中實作樂觀更新，提升使用者體驗
3. **Tag Invalidation**：mutation 後正確失效相關 tags，觸發自動重新獲取
4. **避免手動管理**：不使用 `refetch()`, `setTimeout` 等手動方式

## 實施細節

### 1. 正確的 Tag 提供 (Providing Tags)
```javascript
getBacklogItemsBySprint: builder.query({
  query: (sprintId) => `/api/sprints/${sprintId}/pbis`,
  providesTags: (result, error, sprintId) => 
    result 
      ? [
          { type: 'Sprint', id: sprintId },
          ...result.map(({ id }) => ({ type: 'PBI', id })),
          ...result.flatMap(pbi => 
            pbi.tasks?.map(task => ({ 
              type: 'Task', 
              id: task.id || task.taskId 
            })) || []
          )
        ]
      : [{ type: 'Sprint', id: sprintId }],
})
```

### 2. 樂觀更新 (Optimistic Updates)
```javascript
moveTask: builder.mutation({
  query: ({ ... }) => ({ ... }),
  async onQueryStarted({ sprintId, pbiId, taskId, newState }, { dispatch, queryFulfilled }) {
    // 樂觀更新快取
    const patchResult = dispatch(
      pbiApi.util.updateQueryData('getBacklogItemsBySprint', sprintId, (draft) => {
        const pbi = draft.find(p => p.id === pbiId);
        if (pbi) {
          const task = pbi.tasks?.find(t => t.id === taskId);
          if (task) {
            task.status = newState;
          }
        }
      })
    );
    
    try {
      await queryFulfilled;
    } catch {
      // 失敗時回滾
      patchResult.undo();
    }
  },
  // 成功後失效相關 tags
  invalidatesTags: (result, error, { sprintId, pbiId, taskId }) => [
    { type: 'Sprint', id: sprintId },
    { type: 'PBI', id: pbiId },
    { type: 'Task', id: taskId },
  ],
})
```

### 3. 組件簡化
```javascript
// 不需要手動 refetch 或管理快取
const { data: pbiData } = useGetBacklogItemsBySprintQuery(sprintId, {
  skip: !sprintId
});

// 不需要手動處理樂觀更新
const [moveTask] = useMoveTaskMutation();
await moveTask({ ... }).unwrap();
// RTK Query 自動處理快取更新
```

## 檢查清單
- [ ] 每個 query 都正確提供 tags (`providesTags`)
- [ ] 每個 mutation 都正確失效 tags (`invalidatesTags`)
- [ ] 關鍵 mutations 實作樂觀更新 (`onQueryStarted`)
- [ ] 移除所有手動 `refetch()` 調用
- [ ] 移除所有 `setTimeout` 延遲處理
- [ ] 移除所有 `keepUnusedDataFor: 0` 設定
- [ ] 組件中不手動管理快取狀態

## 後果

### 正面影響
- ✅ 快取管理統一且可預測
- ✅ 自動處理資料同步
- ✅ 樂觀更新提升使用者體驗
- ✅ 減少重複程式碼
- ✅ 避免快取不一致問題

### 負面影響
- ⚠️ 需要理解 RTK Query 的 tag 系統
- ⚠️ 初始設定較複雜
- ⚠️ 需要仔細設計 tag 結構

## 相關文件
- [RTK Query 官方文檔](https://redux-toolkit.js.org/rtk-query/usage/cache-behavior)
- ADR-015: RTK Query 快取策略（已被本 ADR 取代）
- `.ai/tech-stacks/java-ezddd-spring/FAILURE-CASES.md` - 快取相關問題案例

## 修訂歷史
- 2025-08-17：初始決策，徹底解決 RTK Query 快取問題