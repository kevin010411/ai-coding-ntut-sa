# ADR-020: RTK Query 快取策略與 Optimistic Update 的衝突解決

## 狀態
已接受 (Accepted) - 2025-01-18

## 背景與問題描述

### 發現的問題
在 Scrum Board 中，當使用者移動 task 後離開頁面，再回到頁面時會看到舊的資料狀態，需要手動重新整理才能看到正確的資料。

### 問題場景重現
1. 使用者在 Scrum Board 將 task 從 DONE 移動到 TODO
2. Optimistic update 立即更新 UI（task 顯示在 TODO 欄位）
3. 使用者離開 Scrum Board，導航到 Backlog 頁面
4. 使用者返回 Scrum Board
5. **問題：task 又出現在 DONE 欄位（舊狀態）**

### 根本原因分析

#### RTK Query 快取機制
```typescript
// 快取生命週期
keepUnusedDataFor: 30  // 組件卸載後快取保留 30 秒
refetchOnMountOrArgChange: true  // 重新掛載時是否重新取資料
```

#### 問題時序分析
```
T1: 初始狀態 - task 在 DONE（服務器狀態）
T2: 移動 task 到 TODO（optimistic update 修改本地快取）
T3: API 請求成功（服務器更新為 TODO）
T4: 離開頁面（組件 unmount，快取保留在記憶體）
T5: 回到頁面（組件 mount）
    -> RTK Query 檢查快取（還在 keepUnusedDataFor 時間內）
    -> 使用快取資料（但這是 T2 的 optimistic update，不是 T3 的服務器狀態）
```

#### 核心衝突
1. **Optimistic Update 的假設**：本地修改 = 服務器狀態
2. **快取機制的假設**：快取在有效期內 = 資料是最新的
3. **實際情況**：Optimistic update 的快取 ≠ 服務器的真實狀態

### 為什麼 `refetchOnMountOrArgChange: true` 無效？

RTK Query 的邏輯：
```javascript
if (cacheExists && !isExpired) {
  return cachedData;  // 不會重新請求
} else {
  return fetchNewData();
}
```

問題在於 optimistic update 的快取被視為「有效快取」，導致不會重新請求。

## 考慮的方案

### 方案 A：完全禁用快取
```typescript
keepUnusedDataFor: 0  // 組件卸載立即刪除快取
```

**優點：**
- 簡單直接
- 永遠取得最新資料
- 不會有快取不一致問題

**缺點：**
- 每次導航都要重新請求（效能影響）
- 失去快取的優勢
- 網路請求增加

### 方案 B：Optimistic Update 後主動清理快取
```typescript
// moveTask 成功後
async onQueryStarted() {
  try {
    await queryFulfilled;
    // 成功後立即 invalidate
    dispatch(pbiApi.util.invalidateTags([...]));
  }
}
```

**優點：**
- 精確控制快取失效時機
- 保留快取機制的優勢

**缺點：**
- 會導致 UI 閃爍（optimistic update 被覆蓋）
- 使用者體驗不佳（task 會「彈回」原位再移動）

### 方案 C：使用時間戳策略
```typescript
refetchOnMountOrArgChange: 2  // 資料超過 2 秒就重新取
keepUnusedDataFor: 10  // 快取保留 10 秒
```

**優點：**
- 平衡效能和資料新鮮度
- 短時間內導航不會重複請求
- 較長時間後自動更新

**缺點：**
- 仍有短暫的資料不一致視窗（2 秒內）
- 需要調校時間參數

### 方案 D：分離 Optimistic 和實際快取
```typescript
// 標記 optimistic update
const patchResult = dispatch(
  pbiApi.util.updateQueryData('getBacklogItemsBySprint', sprintId, (draft) => {
    draft._isOptimistic = true;  // 標記
  })
);

// 組件掛載時檢查
if (cache._isOptimistic) {
  refetch();  // 強制更新
}
```

**優點：**
- 能區分 optimistic update 和真實資料
- 精確控制何時需要更新

**缺點：**
- 需要修改資料結構
- 增加複雜度
- RTK Query 原生不支援此模式

### 方案 E：組件卸載時清理快取
```typescript
useEffect(() => {
  return () => {
    // 組件卸載時 invalidate
    dispatch(pbiApi.util.invalidateTags([{ type: 'Sprint', id: sprintId }]));
  };
}, [sprintId]);
```

**優點：**
- 保留當前 session 的快取優勢
- 離開頁面後確保下次是新資料

**缺點：**
- 可能過度 invalidate
- 瀏覽器返回按鈕體驗不佳

## 決策考量因素

1. **使用者體驗優先級**
   - 立即回饋 (optimistic update) vs 資料準確性
   - 效能 vs 資料新鮮度

2. **技術限制**
   - RTK Query 的快取機制設計
   - 無法原生區分 optimistic 和真實快取

3. **使用場景**
   - Scrum Board 是協作工具，資料準確性重要
   - 頻繁切換頁面的使用模式

## 決策

經過多次嘗試各種 RTK Query 快取配置後，發現 `keepUnusedDataFor: 0` 並不能真正解決問題。RTK Query 的內部快取機制與 optimistic update 存在根本性衝突。

**最終採用方案：完全繞過 RTK Query，使用原生 fetch API**

### 實作細節

1. **移除 RTK Query hook**：
   - 不再使用 `useGetBacklogItemsBySprintQuery`
   - 改為直接使用 fetch API

2. **資料獲取程式碼**：
```typescript
// 使用 React state 管理資料
const [pbiData, setPbiData] = useState<ProductBacklogItemDto[] | null>(null);

// 直接使用 fetch，完全繞過 RTK Query
useEffect(() => {
  if (!sprintId) return;
  
  const fetchPbis = async () => {
    const response = await fetch(`${API_BASE_URL}/api/sprints/${sprintId}/pbis`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      cache: 'no-store', // 禁用瀏覽器快取
    });
    
    const data = await response.json();
    setPbiData(data);
  };
  
  fetchPbis();
}, [sprintId]);
```

3. **Optimistic Update 處理**：
```typescript
// 先更新本地 state（optimistic update）
if (pbiData) {
  const updatedPbis = pbiData.map(p => {
    if (p.id === pbi.id) {
      // 更新任務狀態
      const updatedTasks = p.tasks?.map(t => 
        t.id === draggedTask.id 
          ? { ...t, status: targetColumn, state: targetColumn }
          : t
      );
      // 更新 PBI 狀態（如果需要）
      return { ...p, tasks: updatedTasks };
    }
    return p;
  });
  setPbiData(updatedPbis);
}

// 再呼叫 API
try {
  await moveTask({ ... }).unwrap();
  // 成功：保持 optimistic update 的狀態
} catch (error) {
  // 失敗：重新 fetch 資料以回復正確狀態
  const response = await fetch(`${API_BASE_URL}/api/sprints/${sprintId}/pbis`);
  const freshData = await response.json();
  setPbiData(freshData);
}
```

4. **RTK Query Mutation 簡化**：
```typescript
// pbiApi.ts - 移除 onQueryStarted，避免雙重更新
moveTask: builder.mutation<...>({
  query: ({ ... }) => ({ ... }),
  // 不做 optimistic update，避免快取衝突
  invalidatesTags: [],
})

## 影響

### 正面影響
- **資料永遠是最新的** - 每次進入頁面都獲取伺服器最新資料
- **不會有快取不一致問題** - 完全避開 RTK Query 快取機制的複雜性
- **簡化除錯和維護** - 資料流程清晰明確
- **解決了根本問題** - 不再有「看到舊資料」的情況

### 負面影響
- **失去 RTK Query 的自動快取管理** - 需要手動管理資料狀態
- **每次導航都會重新請求** - 網路請求次數增加
- **需要手動處理 loading 和 error 狀態** - 不再有 RTK Query 的自動處理

## 學到的教訓

1. **RTK Query 的 `keepUnusedDataFor: 0` 不保證立即清除快取**
   - 內部機制複雜，不一定按預期工作
   - Optimistic update 修改的快取可能被保留

2. **框架的便利性有時會成為限制**
   - 當框架的抽象層造成問題時，使用原生 API 可能更簡單
   - 不要過度依賴框架的「魔法」

3. **測試真實使用場景的重要性**
   - 必須測試「離開頁面再返回」等實際操作流程
   - 單頁面內的測試不足以發現所有問題

## 後續行動

1. ✅ 已實施：使用 fetch API 繞過 RTK Query
2. 監控效能影響，確認沒有造成明顯的效能問題
3. 考慮未來優化：
   - 可以加入簡單的記憶體快取（如 5 秒內不重複請求）
   - 實作 WebSocket 即時更新機制

## 參考資料

- [RTK Query Caching Behavior](https://redux-toolkit.js.org/rtk-query/usage/cache-behavior)
- [Optimistic Updates](https://redux-toolkit.js.org/rtk-query/usage/optimistic-updates)
- Issue: Scrum Board 快取問題（2025-01-18）

## 附錄：最終實作流程

### 原始需求
- T1: 在 Scrum Board，task 在 DONE
- T2: 移動 task 到 TODO，立即移動，同時畫面滑鼠顯示漏斗
- T3: 服務器確認成功，資料庫更新為 TODO（畫面滑鼠顯示正常；如果服務器確認「失敗」，則畫面回復上一狀態）
- T4: 離開 Scrum Board（組件 unmount，「不保留」快取）
- T5: 返回 Scrum Board（看到最新資料）

### 最終實作
1. **直接使用 fetch API** - 不再使用 `useGetBacklogItemsBySprintQuery`，改為直接使用原生 fetch
2. **禁用瀏覽器快取** - 在 fetch 請求中加入 `cache: 'no-store'`
3. **每次進入頁面都重新獲取資料** - 當 sprintId 變化或頁面重新載入時，自動觸發新的 fetch
4. **本地狀態管理** - 使用 React 的 useState 管理 PBI 資料
5. **分離 Optimistic Update 處理**：
   - 在組件中處理 optimistic update（先更新本地 state）
   - RTK Query mutation 只負責 API 呼叫，不更新快取
   - 避免雙重更新造成的 UI 閃爍

### 實際流程
- T1: 在 Scrum Board，task 在 DONE
- T2: 移動 task 到 TODO（optimistic update 立即更新 UI）
- T3: 服務器確認成功，同時更新本地狀態
- T4: 離開 Scrum Board
- T5: 返回 Scrum Board - **每次都會重新 fetch 最新資料，不會有快取問題**

