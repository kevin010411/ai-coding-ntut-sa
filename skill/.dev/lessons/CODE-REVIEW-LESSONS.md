# Code Review 經驗教訓

> 記錄在執行 Code Review 時的失誤與學習，避免重複錯誤

## 2025-08-11: Contract 使用規則檢查失誤

### 問題描述
執行 task-101 (CreateProduct Use Case) code review 時，未正確識別 Value Objects 使用 Contract 的問題，錯誤地將 MUST FIX 項目標記為「建議」。

### 正確規則對照表

| 類型 | 應使用 | 原因 | 違反後果 |
|------|--------|------|----------|
| **Aggregate Root** | `Contract.requireNotNull()` | DBC 框架用於聚合根的契約驗證 | MUST FIX |
| **Entity** | `Objects.requireNonNull()` | 標準 Java 驗證 | MUST FIX |
| **Value Object** | `Objects.requireNonNull()` | 標準 Java 驗證 | MUST FIX |

### 錯誤範例分析

#### ❌ 我產生的錯誤程式碼
```java
// ProductId.java - Value Object
import static tw.teddysoft.ucontract.Contract.*;

public record ProductId(String value) implements ValueObject {
    public ProductId {
        requireNotNull("ProductId value", value);  // ❌ 錯誤使用 Contract
        // 應該使用: Objects.requireNonNull(value, "ProductId value")
    }
}
```

#### ❌ 我的錯誤 Review 結論
```markdown
### 1. Contract 使用一致性
**位置**: Value Objects（ProductId, ProductName, etc.）
**問題**: 使用了 uContract 2.0.0 的 static import
**建議**: Value Objects 通常可以使用 Objects.requireNonNull，但目前的實作也可接受  ❌ 錯誤判斷！
```

#### ✅ 正確的 Review 結論應該是
```markdown
### 🔴 MUST FIX: Value Objects 錯誤使用 Contract
**位置**: ProductId.java, ProductName.java, ProductGoalId.java, GoalMetric.java
**問題**: Value Objects 使用了 Contract.requireNotNull
**嚴重性**: MUST FIX - 違反編碼規範
**修正方式**: 改用 Objects.requireNonNull()
```

### 根因分析
1. **未正確分類檔案類型**：沒有先明確區分哪些是 Aggregate、Entity、Value Object
2. **忽略 MUST 規則**：看到程式可以編譯執行就認為「可接受」
3. **缺乏系統化檢查**：沒有逐一對照檢查清單
4. **誤判嚴重性**：將 MUST FIX 降級為建議

### 改進措施（7步驟檢查流程）

#### Step 1: 檔案分類
```markdown
## 檔案類型分類
- [ ] Aggregate Root: Product.java
- [ ] Value Objects: ProductId.java, ProductName.java, ProductGoalId.java, GoalMetric.java  
- [ ] Entity: ProductGoal.java
```

#### Step 2: 驗證方式檢查
```bash
# 自動化檢查命令
grep -r "implements ValueObject" . -A 10 | grep "Contract\."
grep -r "implements Entity" . -A 10 | grep "Contract\."
```

#### Step 3: 對照規則表
對每個檔案執行：
1. 確認類型（Aggregate/Entity/ValueObject）
2. 檢查實際使用的驗證方式
3. 對照應該使用的驗證方式
4. 記錄是否違規

#### Step 4: 標記嚴重性
- 違反 Contract 使用規則 → **MUST FIX**
- 不能降級為「建議」或「可接受」

#### Step 5: 生成報告前再確認
- 所有 Value Objects 都使用 `Objects.requireNonNull()`？
- 所有 Aggregates 都使用 `Contract.requireNotNull()`？
- 所有 MUST 違規都標記為 MUST FIX？

#### Step 6: 雙重檢查 MUST 規則
從 CODE-REVIEW-CHECKLIST.md 提取所有 MUST 規則，確保無遺漏。

#### Step 7: 最終確認
在標記任務為「通過」前，再次確認所有 MUST FIX 項目都已修正。

### 檢查模板
```markdown
## Domain Layer Contract Usage Check
File: [FileName]
Type: [Aggregate/Entity/ValueObject]
Current: [Contract/Objects]
Expected: [Contract/Objects]
Status: [✅ Correct / ❌ MUST FIX]
```

### 預防機制
1. **建立 pre-review checklist**：在開始 review 前先執行分類
2. **使用自動化腳本**：grep 命令檢查錯誤模式
3. **MUST 規則優先**：先檢查所有 MUST 規則
4. **嚴格執行標準**：不因「能執行」就放寬標準

### 影響範圍
- **直接影響**：task-101 的 4 個 Value Object 檔案需要修正
- **間接影響**：降低了 Code Review 的可信度
- **長期影響**：可能導致其他開發者誤用 Contract

### 學習要點
1. **編碼規範 > 功能正確**：即使程式能執行，違反規範仍需修正
2. **MUST means MUST**：MUST 規則沒有彈性空間
3. **系統化檢查**：使用檢查清單和自動化工具
4. **誠實記錄錯誤**：承認錯誤並記錄下來，避免重複

---

## 重要提醒：uContract 2.0.0 版本變更

### uContract 2.0.0 主要變更
- `reject()` 方法已改名為 `ignore()`
- Contract 仍然使用 `requireNotNull()` 和 `require()` 方法
- import 路徑保持不變：`tw.teddysoft.ucontract.Contract`

### 正確用法範例
```java
// Aggregate Root - 使用 Contract
import static tw.teddysoft.ucontract.Contract.requireNotNull;
public class Product extends EsAggregateRoot<ProductId, ProductEvents> {
    public Product(ProductId productId, String name) {
        requireNotNull("productId", productId);  // ✅ 正確
    }
}

// Value Object - 使用 Objects
import java.util.Objects;
public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value");  // ✅ 正確
    }
}
```

## 檢查清單模板（供未來使用）

### Pre-Review Checklist
- [ ] 執行檔案類型分類
- [ ] 載入 CODE-REVIEW-CHECKLIST.md
- [ ] 標記所有 MUST 規則
- [ ] 準備自動化檢查腳本

### During Review
- [ ] 逐一檢查 MUST 規則
- [ ] 使用自動化腳本輔助
- [ ] 記錄所有違規項目
- [ ] 正確標記嚴重性

### Post-Review
- [ ] 再次確認 MUST 規則
- [ ] 確認違規都標記為 MUST FIX
- [ ] 生成完整報告
- [ ] 更新相關文檔