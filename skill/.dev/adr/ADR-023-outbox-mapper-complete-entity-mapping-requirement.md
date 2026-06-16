# ADR-023: Outbox Mapper 必須完整映射聚合內所有實體

## 狀態
**已採納** (2025-08-24)

## 背景與問題

在實作 Outbox pattern 時，發現了一個嚴重問題：ProductBacklogItemMapper 沒有正確處理 Task 實體的映射，導致：

1. 創建第一個 Task 後能保存到資料庫
2. 但當載入 PBI 並添加第二個 Task 時，第一個 Task 會丟失
3. 這是因為 `toData()` 方法沒有將 Tasks 映射到 TaskData
4. 同時 `toDomain()` 方法在從資料庫重建時也沒有重建 Tasks

### 問題影響
- 資料完整性受損：聚合內的實體在保存/載入循環中丟失
- 業務邏輯失敗：EstimateTask 找不到已創建的 Task
- 測試資料初始化失敗：只有第一個 Task 能成功創建

### 根本原因
Outbox pattern 依賴 Mapper 在以下兩個方向進行完整映射：
- **toData()**: Domain Entity → Data Object (保存到資料庫)
- **toDomain()**: Data Object → Domain Entity (從資料庫載入)

如果任何一個方向的映射不完整，就會造成資料丟失。

## 決策

### 1. Mapper 實作要求

所有 Outbox pattern 的 Mapper 必須：

```java
// toData() 必須映射所有子實體
public static ProductBacklogItemData toData(ProductBacklogItem pbi) {
    ProductBacklogItemData data = new ProductBacklogItemData();
    // ... 基本屬性映射
    
    // 關鍵：必須映射所有子實體集合
    if (pbi.getTasks() != null && !pbi.getTasks().isEmpty()) {
        Set<TaskData> taskDatas = new HashSet<>();
        for (Task task : pbi.getTasks()) {
            TaskData taskData = mapTaskToData(task);
            taskData.setProductBacklogItemData(data);
            taskDatas.add(taskData);
        }
        data.setTaskDatas(taskDatas);
    }
    
    return data;
}

// toDomain() 必須重建所有子實體
public static ProductBacklogItem toDomain(ProductBacklogItemData data) {
    // 使用新的建構子，接受子實體集合作為參數
    List<Task> tasks = reconstructTasksFromData(data.getTaskDatas());
    
    return new ProductBacklogItem(
        // ... 基本參數
        tasks  // 包含重建的子實體
    );
}
```

### 2. 聚合建構子設計

聚合根應提供額外的建構子來支援從資料庫重建：

```java
public class ProductBacklogItem {
    // 標準建構子（用於新建）
    public ProductBacklogItem(ProductId id, String name, ...) {
        // 產生領域事件
    }
    
    // 重建建構子（用於從資料庫載入）
    public ProductBacklogItem(ProductId id, String name, ..., List<Task> tasks) {
        this(id, name, ...);  // 呼叫標準建構子
        
        // 直接設定子實體，不產生額外事件
        if (tasks != null) {
            this.tasks.addAll(tasks);
        }
        
        // 清除重建過程中產生的事件
        this.clearDomainEvents();
    }
}
```

### 3. 驗證機制

建立自動化檢查來確保 Mapper 完整性：
- 單元測試必須驗證 toData() → toDomain() 的往返轉換
- 檢查腳本驗證所有 Mapper 類別的實作完整性
- Code Review 清單包含 Mapper 完整性檢查

## 後果

### 正面影響
- **資料完整性**：確保聚合內所有實體都能正確保存和載入
- **可靠性提升**：避免因映射不完整導致的業務邏輯失敗
- **開發體驗改善**：明確的規範和自動化檢查減少錯誤

### 負面影響
- **複雜度增加**：Mapper 實作變得更複雜
- **維護成本**：新增實體時必須同時更新 Mapper
- **效能考量**：完整映射可能影響效能（但正確性更重要）

## 實作指引

### 檢查清單
當實作或修改 Mapper 時，必須確認：

- [ ] toData() 方法映射了聚合內的所有實體集合
- [ ] toData() 方法正確設定了父子關係（雙向關聯）
- [ ] toDomain() 方法重建了所有子實體
- [ ] toDomain() 使用了適當的建構子避免產生多餘事件
- [ ] 有對應的單元測試驗證往返轉換的正確性
- [ ] 測試包含了具有多個子實體的情境

### 測試範例
```java
@Test
void mapper_should_preserve_all_entities_in_round_trip() {
    // Given: 一個包含多個子實體的聚合
    ProductBacklogItem original = createPbiWithMultipleTasks();
    
    // When: 進行往返轉換
    ProductBacklogItemData data = ProductBacklogItemMapper.toData(original);
    ProductBacklogItem reconstructed = ProductBacklogItemMapper.toDomain(data);
    
    // Then: 所有子實體都應該被保留
    assertEquals(original.getTasks().size(), reconstructed.getTasks().size());
    // 驗證每個 Task 的詳細內容...
}
```

## 相關文件
- `.ai/scripts/check-mapper-compliance.sh` - Mapper 完整性檢查腳本
- `.ai/tech-stacks/java-ezddd-spring/coding-standards.md` - 更新的編碼標準
- `.ai/tech-stacks/java-ezddd-spring/examples/mapper-implementation-guide.md` - Mapper 實作指南

## 參考資料
- Issue: Burndown test data 初始化失敗
- PR: 修復 ProductBacklogItemMapper 缺少 Task 映射問題
- Martin Fowler - Event Sourcing and CQRS patterns