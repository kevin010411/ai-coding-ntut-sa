# ADR-010: Unassigned PBI Query Design

## Status
Accepted

## Date
2025-08-20

## Context
在 Sprint Planning 功能中，需要顯示未被分配到任何 Sprint 的 PBI（Product Backlog Items）列表。我們需要決定如何設計 API 來查詢這些未分配的 PBI。

### 需求分析
1. Sprint Planning 頁面需要顯示可選擇加入 Sprint 的 PBI
2. 這些 PBI 應該是尚未被分配到任何 Sprint 的項目
3. 需要避免傳輸不必要的資料（已在其他 Sprint 中的 PBI）

### 方案比較

#### 方案 A：後端過濾（被採用）
- 修改後端 API 支援查詢未分配的 PBI
- 使用特殊值 `sprintId = "unassigned"` 來表示查詢未分配的 PBI

**優點：**
- ✅ 減少網路傳輸量，只傳輸需要的資料
- ✅ 後端統一處理業務邏輯
- ✅ 可以加入更複雜的篩選邏輯（權限、狀態等）
- ✅ API 設計簡潔，重用現有端點

**缺點：**
- ❌ 需要約定特殊值 "unassigned"
- ❌ 理論上存在 ID 衝突風險（實務上不太可能）

#### 方案 B：前端快取過濾
- 使用 RTK Query 快取所有 PBI，在前端過濾

**優點：**
- ✅ 不需要修改後端
- ✅ 利用快取機制，響應更快

**缺點：**
- ❌ 初次載入較多不必要的資料
- ❌ 前端需要處理複雜的過濾邏輯
- ❌ 可能載入大量用不到的資料

## Decision
採用**方案 A：後端過濾**，使用 `sprintId = "unassigned"` 作為特殊值來查詢未分配的 PBI。

## Implementation Details

### 1. 後端實作

#### UseCase 層
```java
// GetBacklogItemsBySprintService.java
@Override
public GetBacklogItemsBySprintOutput execute(GetBacklogItemsBySprintInput input) {
    // Query backlog items - null sprintId returns unassigned PBIs
    List<ProductBacklogItemDto> backlogItems = 
        productBacklogItemDtoProjection.queryBySprint(input.sprintId);
    // ...
}
```

#### Projection 介面
```java
// ProductBacklogItemDtoProjection.java
/**
 * Query product backlog items by sprint ID.
 * 
 * @param sprintId The ID of the sprint to query PBIs for.
 *                 If null, returns all unassigned PBIs (not in any sprint).
 *                 If not null, returns PBIs assigned to the specified sprint.
 * @return List of ProductBacklogItemDto matching the criteria
 */
List<ProductBacklogItemDto> queryBySprint(String sprintId);
```

#### Controller 層
```java
// GetBacklogItemsBySprintController.java
@GetMapping("/{sprintId}/pbis")
public ResponseEntity<?> getBacklogItemsBySprint(@PathVariable String sprintId) {
    // Handle special case: "unassigned" means null sprintId
    if ("unassigned".equalsIgnoreCase(sprintId.trim())) {
        input.sprintId = null;  // null means unassigned PBIs
    } else {
        input.sprintId = sprintId.trim();
    }
    // ...
}
```

### 2. 前端實作

#### API 定義
```typescript
// backlogApi.ts
getUnassignedBacklogItems: builder.query<BacklogItem[], void>({
  query: () => `/sprints/unassigned/pbis`,  // "unassigned" is a special value
  // ...
})
```

#### 使用方式
```typescript
// ProductBacklogSelectorModal.tsx
const { data: backlogItems, isLoading } = useGetUnassignedBacklogItemsQuery(
  undefined,
  { skip: !isOpen }
);
```

## Consequences

### 正面影響
1. **效能優化**：只傳輸需要的資料，減少網路負擔
2. **API 簡潔**：重用現有端點，不需要新增額外的 API
3. **語意清晰**：`/sprints/unassigned/pbis` 路徑語意明確
4. **擴展性**：後端可以輕易加入更多過濾條件

### 負面影響
1. **魔術字串**：需要約定並文件化 "unassigned" 這個特殊值
2. **潛在風險**：如果真的有 Sprint ID 叫 "unassigned" 會有問題（但實務上應該用 UUID）

### 緩解措施
1. 在 API 文件中明確說明 "unassigned" 的特殊意義
2. 在創建 Sprint 時，驗證 ID 不能是保留字 "unassigned"
3. 考慮未來使用查詢參數（如 `?unassigned=true`）來替代路徑參數

## Related ADRs
- ADR-001: UseCase 套件結構
- ADR-002: ORM 配置位置

## References
- REST API Design Best Practices
- Spring Boot REST Controller Documentation