# ADR-015: RTK Query 快取策略

## 狀態
已接受 (Accepted)

## 日期
2025-08-17

## 背景
在 Scrum Board 開發過程中，發現多次快取相關問題：
1. 頁面導航回 Scrum Board 時顯示舊資料
2. 需要手動重新整理才能看到最新狀態
3. 任務移動後狀態不一致

這些問題影響了使用者體驗，需要建立系統性的快取策略。

## 決策
採用以下 RTK Query 快取策略：

### 1. 關鍵資料零快取策略
對於需要即時更新的資料（如 Sprint Board 的 PBI 和 Task），設定：
```javascript
{
  keepUnusedDataFor: 0,
  refetchOnMountOrArgChange: true,
  refetchOnFocus: true,
}
```

### 2. Mutation 後完整失效
每個 mutation 必須失效所有相關的快取標籤，並使用 `onQueryStarted` 確保立即失效：
```javascript
async onQueryStarted(arg, { dispatch, queryFulfilled }) {
  try {
    await queryFulfilled;
    // 強制失效相關查詢
    dispatch(api.util.invalidateTags([...]));
  } catch {}
},
invalidatesTags: [
  { type: 'Sprint', id: sprintId },
  { type: 'PBI', id: pbiId },
  'Task', // 失效所有任務
]
```

### 3. 組件層級強制重新獲取
在關鍵組件（如 Scrum Board）掛載時強制重新獲取：
```javascript
useEffect(() => {
  if (sprintId) {
    refetchPbis();
  }
}, [sprintId]);
```

### 4. 統一配置
通過 `baseApi.ts` 提供預設配置，但允許個別端點覆寫。

## 原因
1. **資料一致性**：確保使用者看到最新資料
2. **使用者體驗**：避免需要手動重新整理
3. **簡單性**：寧可多次請求也要確保資料正確
4. **可預測性**：行為一致，易於除錯

## 後果

### 正面影響
- ✅ 消除快取不一致問題
- ✅ 使用者總是看到最新資料
- ✅ 減少快取相關的 bug
- ✅ 簡化除錯過程

### 負面影響
- ⚠️ 增加 API 請求次數
- ⚠️ 可能影響效能（但對小型專案影響有限）
- ⚠️ 網路流量增加

## 實施細節

### 1. pbiApi.ts 配置
```javascript
getBacklogItemsBySprint: builder.query({
  query: (sprintId) => `/api/sprints/${sprintId}/pbis`,
  keepUnusedDataFor: 0,
  refetchOnMountOrArgChange: true,
  refetchOnFocus: true,
})
```

### 2. ScrumBoardWithSwimlanes.tsx 強制重新獲取
```javascript
const { data, refetch } = useGetBacklogItemsBySprintQuery(sprintId, {
  skip: !sprintId,
  refetchOnMountOrArgChange: true
});

useEffect(() => {
  if (sprintId) {
    refetch();
  }
}, [sprintId]);
```

### 3. 檢查清單
- [ ] 所有關鍵查詢設定 `keepUnusedDataFor: 0`
- [ ] 所有 mutation 正確設定 `invalidatesTags`
- [ ] 關鍵頁面在掛載時強制重新獲取
- [ ] 測試頁面切換後資料是否更新

## 替代方案
1. **完全停用快取**：過於極端，影響效能
2. **使用 WebSocket**：過於複雜，不符合專案規模
3. **手動管理 Redux 狀態**：增加複雜度，違反 RTK Query 設計理念

## 相關文件
- `.ai/tech-stacks/java-ezddd-spring/FAILURE-CASES.md` - 記錄的快取相關問題
- `frontend/src/api/baseApi.ts` - 統一快取配置
- `frontend/src/api/pbiApi.ts` - PBI API 快取設定

## 修訂歷史
- 2025-08-17：初始決策，解決 Scrum Board 快取問題
- 2025-08-17：增加組件層級強制重新獲取策略