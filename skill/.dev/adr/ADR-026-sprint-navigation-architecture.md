# ADR-009: Sprint Navigation Architecture and Page Transition Logic

## Status
Accepted

## Context
我們需要重新設計 Sprint 相關功能的導航架構，以提供更清晰的使用者體驗。原本的設計將 Sprint Planning 作為 Sprint 列表頁面的一個 tab，但這造成了概念上的混淆，因為 Sprint Planning 應該是針對特定 Sprint 的操作，而不是與 Sprint 列表並列的功能。

### 原始問題
1. Sprint Planning 和 Sprint 列表在同一個頁面以 tab 形式呈現，概念不清
2. 沒有明確的層級結構來區分 Sprint 管理和特定 Sprint 的操作
3. 使用者進入 Sprint 功能時，不清楚當前的操作範圍

## Decision

### 1. 兩層導航架構
實作兩層導航系統：

**第一層（主導航）**：
- Product Backlog - 產品待辦事項清單
- All Sprints - 所有 Sprint 列表

**第二層（Sprint 子導航）**：
僅在選擇特定 Sprint 後顯示：
- Sprint Planning - Sprint 規劃
- Scrum Board - Scrum 看板  
- Retrospective - 回顧會議
- Team - 團隊管理
- Setting - 設定

### 2. 智能跳轉邏輯
從 Sprint 列表點擊特定 Sprint 時的跳轉規則：

```typescript
if (sprint.state === 'PLANNED') {
  // Sprint 尚未開始，跳轉到 Sprint Planning
  navigate(`/sprint-planning?sprintId=${sprintId}`);
} else {
  // Sprint 已開始或其他狀態，跳轉到 Scrum Board
  navigate(`/scrum-board?sprintId=${sprintId}`);
}
```

### 3. 頁面保護機制
在 Sprint Planning 頁面實作狀態檢查：
- 如果當前 Sprint 不是 `PLANNED` 狀態，自動重導向到 Scrum Board
- 確保使用者始終在正確的頁面操作

### 4. 第二層選單顯示邏輯
```typescript
// 只在有特定 Sprint 被選中時顯示第二層選單
const showSecondLevelMenu = isSprintContext && sprintId;
```

## Implementation Details

### 檔案結構
```
src/pages/
├── SprintListPage.tsx        # Sprint 列表頁面（無 tabs）
├── SprintPlanningPageNew.tsx # Sprint Planning 頁面
├── ScrumBoardWithSwimlanes.tsx # Scrum Board 頁面
└── ...

src/components/
└── SprintNavigation.tsx      # 第二層導航元件
```

### URL 結構
```
/sprints                       # Sprint 列表（無 sprintId，不顯示第二層選單）
/sprint-planning?sprintId=xxx  # Sprint Planning（有 sprintId，顯示第二層選單）
/scrum-board?sprintId=xxx      # Scrum Board（有 sprintId，顯示第二層選單）
/retrospective?sprintId=xxx    # 回顧會議（有 sprintId，顯示第二層選單）
/team?sprintId=xxx             # 團隊管理（有 sprintId，顯示第二層選單）
/setting?sprintId=xxx          # 設定（有 sprintId，顯示第二層選單）
```

### 狀態管理
- 使用 URL query parameter (`sprintId`) 來維持當前選中的 Sprint
- 在第二層選單切換時保持 `sprintId` 參數
- 透過 `useLocation` 和 `URLSearchParams` 讀取當前狀態

## Consequences

### 優點
1. **清晰的層級結構**：使用者明確知道自己在操作哪個層級
2. **智能導航**：根據 Sprint 狀態自動引導使用者到正確頁面
3. **上下文保持**：在 Sprint 內部操作時始終保持當前 Sprint 的選擇
4. **減少混淆**：Sprint Planning 不再與 Sprint 列表並列，而是作為特定 Sprint 的操作
5. **更好的可擴展性**：未來可以輕鬆新增更多 Sprint 相關功能到第二層選單

### 缺點
1. **額外的導航層級**：使用者需要理解兩層導航的概念
2. **URL 參數依賴**：系統依賴 URL query parameter 來維持狀態
3. **重構成本**：需要重構現有的頁面結構和路由配置

## Related Decisions
- ADR-008: UI Development Timing Decision
- 未來可能需要考慮將 Sprint 狀態存入全域狀態管理（Redux）

## Notes
- 第一層導航文字從 "Backlog" 改為 "Product Backlog"，從 "Sprint" 改為 "All Sprints"，使功能範圍更明確
- Sprint Planning 頁面會顯示當前 Sprint 名稱在標題中
- 所有第二層選單項目都會保持 `sprintId` 參數，確保上下文不會遺失

## Date
2024-01-20