# 前端除錯檢討報告 - EditTaskModal 備註欄位問題

**日期**: 2024-08-21  
**問題**: EditTaskModal 的備註欄位無法顯示資料，即使後端 API 有正確的 note 內容  
**解決時間**: 約 2 小時  
**根本原因**: TypeScript 型別定義不完整導致資料被過濾  

## 🚨 錯誤的除錯流程

### 1. 誤判為 API 端點問題 (❌ 錯誤方向)
```
以為問題: /api vs /v1/api 路徑不一致
實際檢查: curl 兩個端點，發現資料完全一樣
浪費時間: 30 分鐘修改各種 API 路徑
```

### 2. 過度複雜化快取處理 (❌ 過度工程)
```typescript
// 錯誤: 複雜的 onQueryStarted 處理
async onQueryStarted({ pbiId, taskId, sprintId }, { dispatch, queryFulfilled }) {
  // 大量複雜的 cache invalidation 邏輯
}

// 正確: 簡單的 invalidatesTags 就足夠
invalidatesTags: (result, error, { pbiId, taskId, sprintId }) => [
  { type: 'PBI', id: pbiId },
  { type: 'Task', id: taskId },
  { type: 'Sprint' as const },
]
```

### 3. 沒有及早檢查資料流 (❌ 盲點)
- 沒有檢查前端實際收到的資料結構
- 沒有檢查 TypeScript 型別定義
- 直接假設是快取同步問題

## ✅ 正確的除錯流程

### 步驟 1: 驗證後端資料
```bash
# 檢查後端 API 是否有正確資料
curl -s http://localhost:9090/v1/api/sprints/sprint-test-001/pbis | jq '.[] | .tasks[] | {id, note}'
curl -s http://localhost:9090/v1/api/pbis/pbi-test-001/tasks | jq '.[] | {id, note}'
```

### 步驟 2: 檢查前端型別定義
```typescript
// 問題: ScrumBoard 的 Task 介面缺少 note 欄位
interface Task {
  id: string;
  name: string;
  // note?: string;  ← 缺少這個！
  state: 'TODO' | 'DOING' | 'TESTING' | 'REVIEW' | 'DONE';
  pbiId: string;
}
```

### 步驟 3: 檢查資料傳遞鏈
```
API Response → TypeScript Interface → Component Props → useState
```

### 步驟 4: 加入 Debug 日誌
```typescript
console.log('Raw task object:', task);
console.log('task.note:', task.note);
console.log('task.description:', task.description);
```

## 🎯 根本原因與解決方案

### 根本原因
**TypeScript 型別定義不完整**：ScrumBoard 使用的本地 `Task` 介面缺少 `note`, `description`, `title`, `estimatedHours` 等欄位。

### 解決方案選項

#### 選項 1: 修正型別定義 (✅ 採用)
```typescript
interface Task {
  id: string;
  name: string;
  title?: string;        // 新增
  note?: string;         // 新增
  description?: string;  // 新增
  estimatedHours?: { value: number }; // 新增
  state: 'TODO' | 'DOING' | 'TESTING' | 'REVIEW' | 'DONE';
  pbiId: string;
}
```

#### 選項 2: 統一使用 TaskDto (更好的長期方案)
```typescript
import type { TaskDto } from '@/api/pbiApi';

// 直接使用 API 定義的型別，避免重複定義
interface PBI {
  tasks?: TaskDto[];  // 不用本地 Task 型別
}
```

#### 選項 3: Runtime 資料補強 (暴力解法)
```typescript
// EditTaskModal 直接從 API 重新抓取資料
const { data: taskData } = useGetTasksByPbiQuery(pbiId);
const freshTask = taskData.find(t => t.id === task.id);
```

## 📚 學到的教訓

### 1. 除錯優先順序
```
1. 檢查資料源 (後端 API)
2. 檢查型別定義 (TypeScript interfaces)  
3. 檢查資料傳遞 (Component props)
4. 檢查狀態管理 (useState, 快取)
5. 檢查 UI 渲染 (DOM, CSS)
```

### 2. RTK Query 快取機制
- 不同的 `query` 有獨立的快取條目
- `getBacklogItemsBySprint` ≠ `getTasksByPbi` 
- `invalidatesTags` 只影響有相同 tag 的查詢
- 型別定義會影響快取資料的可用性

### 3. TypeScript 最佳實務
- **統一型別定義**: 避免重複定義相同的資料結構
- **完整型別定義**: 確保包含所有需要的欄位
- **型別即文件**: 型別定義是前後端的契約

### 4. Debug 技巧
```typescript
// 好的 debug 方式
console.log('=== Component Debug ===');
console.log('Raw data:', data);
console.log('Specific field:', data?.field);
console.log('Type check:', typeof data?.field);
console.log('========================');

// 避免的 debug 方式
console.log(data); // 太簡略
console.log('data', data.field); // 可能 undefined error
```

## 🚫 避免再犯的檢查清單

### 前端資料問題除錯 SOP
1. [ ] **驗證後端 API** - 用 curl 檢查實際回傳資料
2. [ ] **檢查型別定義** - 確認 TypeScript interface 包含所需欄位
3. [ ] **檢查資料傳遞** - console.log 每個環節的資料
4. [ ] **檢查快取策略** - 確認 RTK Query tags 設定正確
5. [ ] **簡化除錯** - 先用最簡單的方法，不要過度工程

### 型別定義最佳實務
1. [ ] **統一來源** - 優先使用 API 定義的型別 (如 TaskDto)
2. [ ] **完整定義** - 包含所有可能用到的欄位
3. [ ] **選用欄位** - 使用 `?:` 標記非必要欄位
4. [ ] **定期同步** - API 變更時同步更新型別定義

### 快取處理原則
1. [ ] **先基本功能** - 確保不用快取時功能正常
2. [ ] **簡單 invalidation** - 優先使用 `invalidatesTags`
3. [ ] **避免複雜邏輯** - 不要使用 `onQueryStarted` 除非必要
4. [ ] **測試快取行為** - 驗證資料更新後的同步性

## 🎯 結論

這次問題的核心是**型別定義不完整**，不是快取問題。我在除錯時：
1. 誤判了問題方向 (API vs 型別)
2. 過度複雜化了解決方案 (快取處理)
3. 沒有遵循系統化的除錯流程

正確的方法應該是：**從資料流的源頭開始檢查，一步步向下追蹤**，而不是先入為主地假設問題所在。

**記住**: TypeScript 的型別定義就是資料的契約，缺少欄位定義等於資料不存在。