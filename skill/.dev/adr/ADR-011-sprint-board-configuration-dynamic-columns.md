# ADR-011: Sprint Board Configuration 動態欄位顯示

## 狀態
已接受 (Accepted)

## 背景
在 Scrum Board 的實作中，不同的團隊對於任務狀態的需求可能不同。有些團隊需要 Testing 階段，有些需要 Review 階段，有些兩者都需要，有些都不需要。原本的實作是在前端寫死這些欄位，缺乏彈性。

## 決策
我們決定將 Sprint Board 的欄位配置儲存在 Sprint 實體中，透過 `SprintBoardConfig` 來控制哪些欄位要顯示：

1. **新增 SprintBoardConfig Value Object**
   ```java
   public record SprintBoardConfig(
       boolean enableTest,
       boolean enableReview
   ) implements ValueObject
   ```

2. **Sprint 實體包含配置**
   - Sprint 實體新增 `sprintBoardConfig` 屬性
   - 可透過 `configBoardTaskState()` 方法更新配置
   - 產生 `SprintBoardConfigured` domain event

3. **API 層面傳遞配置**
   - SprintDto 包含 `sprintBoardConfig` 欄位
   - 前端透過 API 獲取 Sprint 資料時一併取得配置

4. **前端動態顯示**
   - 根據 `enableTest` 決定是否顯示 Testing 欄位
   - 根據 `enableReview` 決定是否顯示 Review 欄位
   - 預設值：兩者都是 false（不顯示）

## 影響

### 正面影響
1. **彈性配置** - 每個 Sprint 可以有不同的看板配置
2. **使用者體驗** - 團隊可以根據自己的工作流程客製化看板
3. **資料完整性** - 配置與 Sprint 綁定，確保資料一致性
4. **Event Sourcing** - 配置變更會產生 domain event，可追蹤歷史

### 負面影響
1. **複雜度增加** - 需要額外的 DTO、Mapper 和 API
2. **前端邏輯** - 前端需要處理動態欄位的顯示邏輯
3. **測試複雜度** - 需要測試不同配置組合的情況

## 其他考慮的方案

### 方案 1：前端寫死配置
- 優點：簡單直接
- 缺點：缺乏彈性，所有 Sprint 都相同

### 方案 2：全域配置
- 優點：一次設定，全部適用
- 缺點：無法針對不同 Sprint 客製化

### 方案 3：更彈性的欄位配置
- 允許自定義欄位名稱和數量
- 優點：最大彈性
- 缺點：過度設計，增加大量複雜度

## 決策理由
選擇目前的方案是因為：
1. 提供足夠的彈性滿足大部分團隊需求
2. 實作複雜度適中
3. 符合 DDD 設計原則，配置是 Sprint 的一部分
4. 可以透過 Event Sourcing 追蹤配置變更

## 實作細節

### 後端實作
1. `SprintBoardConfig` - Value Object
2. `SprintBoardConfigDto` - DTO
3. `SprintBoardConfigMapper` - 轉換邏輯
4. `SprintMapper` - 更新以包含配置映射
5. `ConfigScrumBoardTaskStateUseCase` - 更新配置的 use case

### 前端實作
1. 更新 `SprintDto` type 定義
2. `ScrumBoardPage` 使用 `useGetSprintQuery` 獲取配置
3. `getBoardColumns()` 根據配置動態返回欄位

### API 端點
- GET `/v1/api/sprints/{sprintId}` - 返回包含配置的 Sprint 資料
- PUT `/v1/api/sprints/{sprintId}/board-config` - 更新看板配置

## 參考資料
- Sprint entity 設計
- Event Sourcing 模式
- React 動態渲染實作