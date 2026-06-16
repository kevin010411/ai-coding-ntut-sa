# ADR-025: Mutation Testing 與 uContract 排除策略

## 狀態
已採納 (Accepted)

## 背景
在執行 PIT mutation testing 評估 entity layer 測試有效性時，發現：

1. **uContract 產生大量無意義的變異**
   - 總 mutations 從 986 增加到 1,652（增加 67%）
   - ProductBacklogItem 從 464 增加到 689 mutations（增加 48%）
   - 這些 Contract 相關變異拉低了整體 mutation score

2. **實際測試結果對比**
   - 包含 uContract: Mutation Score 32%, Test Strength 62%
   - 排除 uContract: Mutation Score 39%, Test Strength 86%
   - Product.entity 實際覆蓋率從 51% 提升到 76%

3. **uContract 的本質**
   - uContract 是 Design by Contract (DbC) 的實作工具
   - 用來定義程式行為的前置條件(preconditions)、後置條件(postconditions)和不變量(invariants)
   - **不是防禦性編程，也不是業務邏輯**

## 決策

### 核心原則
1. **所有 mutation testing 執行時必須排除 uContract 套件的變異**
2. **uContract 搭配適當的測試策略可以取代部分傳統測試**

### PIT 配置規範
```xml
<configuration>
    <!-- 排除 uContract package 從變異測試 -->
    <avoidCallsTo>
        <avoidCallsTo>tw.teddysoft.ucontract.Contract</avoidCallsTo>
        <avoidCallsTo>tw.teddysoft.ucontract</avoidCallsTo>
    </avoidCallsTo>
</configuration>
```

### 測試策略
1. **Use Case Test + uContract**: 透過 Use Case 測試觸發 Contract 檢查
2. **Unit Test + uContract**: 直接測試 Aggregate 行為，Contract 自動驗證不變量
3. **Assertion-free Test**: 依賴 Contract 進行驗證，減少冗餘的斷言

## 原因

### 為什麼要排除 uContract

1. **Contract 不是被測試的對象**
   - Contract 定義了程式的規格(specification)
   - 它們是驗證工具，不是需要被測試的業務邏輯

2. **更準確的覆蓋率指標**
   - 排除後的 mutation score 真實反映業務邏輯覆蓋率
   - Test Strength 從 62% 提升到 86%，顯示測試品質其實很好

3. **減少測試噪音**
   - 避免為了提升 mutation score 而寫無意義的 Contract 測試
   - 專注於真正的業務邏輯測試

### Design by Contract 的價值

1. **Contract 即文檔**
   - 前置/後置條件清楚定義方法的行為
   - 不變量確保物件狀態的一致性

2. **Runtime 驗證**
   - 在開發和測試階段自動捕捉違反契約的情況
   - 減少需要撰寫的顯式測試案例

3. **提升程式品質**
   - 強制思考和明確定義程式行為
   - 早期發現設計問題

## 影響

### 正面影響
- ✅ Mutation score 更準確地反映實際測試品質
- ✅ 減少不必要的測試工作量
- ✅ 鼓勵正確使用 Design by Contract
- ✅ 測試更專注於業務邏輯

### 需要注意
- ⚠️ 團隊成員需要理解 DbC 概念
- ⚠️ 必須在所有環境統一配置 PIT
- ⚠️ Code review 時要確認 Contract 的正確使用

## 實施指南

1. **立即行動**
   - 更新所有 PIT 配置檔案，加入 uContract 排除設定
   - 在 CI/CD pipeline 中統一配置

2. **團隊教育**
   - 說明 Design by Contract 的概念和價值
   - 分享 uContract 的最佳實踐

3. **監控指標**
   - 追蹤排除後的 mutation coverage 趨勢
   - 定期檢視 Contract 的使用情況

## 實戰經驗與教訓 (2025-08-28 更新)

### 關鍵學習：增強既有程式碼的 Contract

在嘗試為 ProductBacklogItem 加入 Contract 以提升 mutation coverage 時，我們學到了重要的經驗：

#### ❌ 錯誤作法：一次性加入大量 Contract
```java
// 錯誤：過度限制性的 preconditions
require("Task name must be meaningful", () -> 
    name.trim().length() >= 3 && name.trim().length() <= 200);
require("PBI must be in valid state for task creation", () -> 
    state == PbiState.SELECTED || state == PbiState.IN_PROGRESS);
require("Valid state transition", () -> 
    isValidStateTransition(fromState, newState));
```
**結果**：71 個測試中有 17 個失敗，因為新加入的 Contract 改變了既有行為。

#### ✅ 正確作法：漸進式加入 Contract
```java
// 步驟 1：加入簡單驗證
require("Task name must not be empty", () -> !name.trim().isEmpty());
// 測試通過 ✓

// 步驟 2：加入防止重複的驗證
require("Cannot create duplicate task", () -> 
    !tasks.stream().anyMatch(t -> t.getId().equals(taskId)));
// 測試通過 ✓

// 步驟 3：加入 postcondition
ensure("Task is in the task list", () -> 
    tasks.stream().anyMatch(t -> t.getId().equals(taskId)));
// 測試通過 ✓
```
**結果**：所有 71 個測試都通過，mutation coverage 從 36% 提升到 39%。

### 實施原則

1. **理解既有行為**
   - 在加入 Contract 前，必須深入理解方法的既有行為
   - Contract 應該「描述」而非「改變」既有邏輯

2. **漸進式實施**
   - 每次只加入一個小的 Contract
   - 立即執行測試確認沒有破壞既有功能
   - 確認通過後才加入下一個 Contract

3. **Contract 優先順序**
   - 優先加入 postconditions（驗證結果正確性）
   - 其次加入 invariants（維護資料一致性）
   - 謹慎加入 preconditions（避免過度限制）

4. **與測試協同演進**
   - Contract 不應該與既有測試衝突
   - 如果 Contract 導致測試失敗，優先檢視 Contract 是否過於嚴格
   - Contract 應該補強而非取代既有測試

### 實際成效

透過謹慎地加入 Contract，我們實現了：
- **測試相容性**：100% 既有測試通過（71/71）
- **Mutation Coverage 提升**：36% → 39%（+3%）
- **程式碼品質**：更明確的行為規範和資料一致性保證

### 建議工作流程

```bash
# 1. 執行基準測試
mvn test -Dtest='*Test'

# 2. 加入一個 Contract
# 編輯程式碼...

# 3. 立即測試
mvn test -Dtest='*Test'

# 4. 如果測試失敗，立即回滾
git checkout -- <file>

# 5. 如果測試通過，提交變更
git add -p
git commit -m "Add contract: [specific validation]"

# 6. 定期執行 mutation testing 驗證改善
mvn org.pitest:pitest-maven:mutationCoverage
```

## 參考資料
- [Design by Contract - Bertrand Meyer](https://en.wikipedia.org/wiki/Design_by_contract)
- [uContract Documentation](https://github.com/teddysoft/ucontract)
- [PIT Mutation Testing](https://pitest.org/)
- 實際測試數據：從 1,652 mutations 減少到 986 mutations（減少 40%）

## 決策記錄
- 日期：2025-08-28
- 決策者：開發團隊
- 審查者：技術負責人