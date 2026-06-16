# Hours 從 Integer 改為 BigDecimal 的變更日誌

## 變更日期
2025-08-17

## 變更摘要
將 `Hours` 值物件的內部實作從 `Integer` 改為 `BigDecimal`，以支援小數時數的精確計算。

## 變更原因
1. **業務需求**：需要支援更精確的時間估算，如 0.5 小時（30分鐘）、1.5 小時（90分鐘）等
2. **精度問題**：使用 Integer 無法表示小數，限制了估算的精確度
3. **計算準確性**：BigDecimal 提供精確的小數運算，避免浮點數精度問題

## 影響範圍

### 核心類別
- `tw.teddysoft.aiscrum.common.entity.Hours` - 值物件本身
- `tw.teddysoft.aiscrum.pbi.entity.EstimatedHours` - 預估時數
- `tw.teddysoft.aiscrum.pbi.entity.RemainingHours` - 剩餘時數
- `tw.teddysoft.aiscrum.sprint.entity.CapacityHours` - 容量時數

### DTO 類別
- `EstimatedHoursDto` - 改為使用 BigDecimal
- `RemainingHoursDto` - 改為使用 BigDecimal
- `CapacityHoursDto` - 改為使用 BigDecimal

### Mapper 類別
- `EstimatedHoursMapper` - 更新轉換邏輯
- `RemainingHoursMapper` - 更新轉換邏輯
- `CapacityHoursMapper` - 更新轉換邏輯

### 業務邏輯
- `ProductBacklogItem.reestimateTask()` - 使用 BigDecimal 的 add/subtract/compareTo 方法

## API 變更
### 輸入格式
- 支援小數格式：`"0.5"`, `"1.5"`, `"2.8"` 等
- 向下相容：整數格式仍然支援 `"1"`, `"2"`, `"3"`

### 輸出格式
- 使用 `stripTrailingZeros().toPlainString()` 格式化
- 例如：`1.5` 顯示為 `"1.5"`，`2.0` 顯示為 `"2"`

## 使用範例

### 創建任務時設定預估時數
```json
{
  "productId": "prod-123",
  "taskId": "task-456",
  "name": "實作登入功能",
  "estimatedHours": 1.5
}
```

### 估算任務
```json
{
  "productId": "prod-123",
  "estimatedHours": 0.5
}
```

### 重新估算任務
```json
{
  "productId": "prod-123",
  "estimatedHours": 2.5,
  "reason": "發現需要額外的測試時間"
}
```

## 程式碼範例

### 使用 Hours 類
```java
// 從各種格式創建
Hours hours1 = Hours.valueOf("0.5");           // 從字串
Hours hours2 = Hours.valueOf(1.5);              // 從 double
Hours hours3 = Hours.valueOf(new BigDecimal("2.25")); // 從 BigDecimal
Hours hours4 = Hours.valueOf(3);                // 從整數

// 運算
Hours total = hours1.add(hours2);               // 0.5 + 1.5 = 2
Hours diff = hours3.subtract(hours1);           // 2.25 - 0.5 = 1.75
```

## 注意事項

1. **精度處理**：內部使用 BigDecimal，保證精確計算
2. **驗證規則**：
   - 時數不可為負數
   - 時數不可超過 99999
3. **向下相容**：仍支援整數輸入，會自動轉換為 BigDecimal

## 測試重點

1. **小數輸入測試**：確認 0.5, 1.5, 2.8 等小數值能正確處理
2. **運算測試**：確認加減法運算結果正確
3. **邊界測試**：確認負數和超大值的驗證
4. **格式化測試**：確認輸出格式正確（去除不必要的零）

## 相關文件
- [Hours 實體規格](./common/entity/hours-spec.json)
- [CreateTask Use Case 規格](./pbi/usecase/create-task.json)
- [EstimateTask Use Case 規格](./pbi/usecase/estimate-task.json)
- [ReestimateTask Use Case 規格](./pbi/usecase/reestimate-task.json)