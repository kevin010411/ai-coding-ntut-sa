# ADR-006: REST API 路徑設計原則

## 狀態
已採納 (Accepted) - 2025-08-15

## 背景
在設計 REST API 時，我們面臨如何表達 Aggregate Root 之間關係的問題。特別是當一個資源（如 Product Backlog Item）必須屬於另一個資源（如 Product）時，API 路徑該如何設計？

初始設計有兩種選擇：
1. 扁平路徑：`POST /v1/api/pbis` (body 含 productId)
2. 巢狀路徑：`POST /v1/api/products/{productId}/pbis`

## 決策
採用「**用巢狀的建立端點、用扁平的資源位址**」的混合設計模式。

### 具體規則

#### 1. 建立（Create）操作
使用巢狀路徑表達歸屬關係：
- `POST /v1/api/products/{productId}/pbis` - 在特定 Product 下建立 PBI
- `POST /v1/api/pbis/{pbiId}/tasks` - 在特定 PBI 下建立 Task

#### 2. 資源操作（Read/Update/Delete）
使用扁平路徑尊重資源獨立性：
- `GET /v1/api/pbis/{pbiId}` - 查詢單筆 PBI
- `PATCH /v1/api/pbis/{pbiId}` - 更新 PBI
- `DELETE /v1/api/pbis/{pbiId}` - 刪除 PBI

#### 3. 集合查詢
可同時提供兩種路徑：
- `GET /v1/api/pbis` - 查詢所有 PBI（可用 query parameter 過濾）
- `GET /v1/api/products/{productId}/pbis` - 查詢特定 Product 的 PBI

## 理由

### 1. 符合 DDD 原則
- **Aggregate Root 獨立性**：每個 Aggregate Root 有自己的識別與生命週期，扁平資源路徑體現這種獨立性
- **Aggregate 邊界**：Aggregate 之間只透過 ID 引用，不直接包含

### 2. REST 語意清晰
- **建立語意**：巢狀路徑清楚表達「在哪個集合中新增」
- **資源語意**：扁平路徑表達「這是一個獨立的資源」
- **錯誤處理直觀**：父資源不存在時返回 404 很自然

### 3. 實務優點
- **授權簡化**：巢狀建立端點可在路徑層級做授權檢查
- **API 彈性**：資源可能在 Aggregate 間移動時，扁平路徑不需改變
- **客戶端友好**：建立時的巢狀路徑提供上下文，操作時的扁平路徑簡潔

## 範例

### Product Backlog Item (PBI)
```
POST   /v1/api/products/{productId}/pbis    # 建立
GET    /v1/api/pbis/{pbiId}                 # 查詢
PATCH  /v1/api/pbis/{pbiId}                 # 更新
DELETE /v1/api/pbis/{pbiId}                 # 刪除
GET    /v1/api/products/{productId}/pbis    # 列表
```

### Task
```
POST   /v1/api/pbis/{pbiId}/tasks          # 建立
GET    /v1/api/tasks/{taskId}              # 查詢
PATCH  /v1/api/tasks/{taskId}              # 更新
DELETE /v1/api/tasks/{taskId}              # 刪除
GET    /v1/api/pbis/{pbiId}/tasks          # 列表
```

## 例外情況

### 何時可用扁平建立端點？
1. 批次建立操作：`POST /v1/api/pbis:batchCreate`
2. 匯入功能：`POST /v1/api/pbis:import`
3. 客戶端限制：當客戶端難以組出巢狀路徑時

即使提供扁平變體，仍應：
- 在 request body 中要求 productId
- 檢查父資源存在性
- 不存在時返回 404

## 影響

### 正面影響
- API 設計一致性提高
- 減少路徑設計的爭議
- 符合業界最佳實踐

### 負面影響
- 需要同時維護兩種路徑模式
- 可能增加初學者的學習曲線

## 參考資料
- RESTful API Design Best Practices
- Domain-Driven Design by Eric Evans
- REST API Design Rulebook by Mark Massé