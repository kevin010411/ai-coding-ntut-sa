# ADR-014: 禁止自定義 Repository 介面

## 狀態
已接受 (Accepted)

## 日期
2025-08-17

## 背景
在程式碼審查中發現專案中存在多個自定義 Repository 介面（如 `ProductBacklogItemRepository`、`ProductRepository`、`SprintRepository`），這些介面繼承自 `Repository<T, ID>` 但沒有添加任何額外方法。這違反了 DDD 和 Event Sourcing 架構的設計原則。

### 發現的問題
1. 創建了不必要的抽象層
2. 違反了框架設計規範（Repository 只能有三個方法）
3. 增加了程式碼複雜度但沒有帶來價值
4. 容易誘導開發者在 Repository 中添加自定義查詢方法

## 決策
**絕對禁止創建自定義 Repository 介面**。所有需要使用 Repository 的地方必須直接使用 generic `Repository<Aggregate, AggregateId>`。

### 具體規範
1. **禁止**：`interface ProductRepository extends Repository<Product, ProductId>`
2. **必須**：直接注入 `Repository<Product, ProductId>`
3. Repository 只能使用三個標準方法：
   - `findById(ID id)`
   - `save(T aggregate)`
   - `delete(T aggregate)`
4. 查詢需求使用 Projection 或 Query Service 處理

## 原因
1. **遵循框架設計**：ezddd 框架明確規定 Repository 只能有三個方法
2. **簡化架構**：減少不必要的抽象層
3. **防止違規**：避免開發者在 Repository 添加自定義查詢方法
4. **CQRS 原則**：查詢和命令分離，查詢走 Projection，命令走 Repository

## 後果

### 正面影響
- ✅ 程式碼更簡潔，減少不必要的介面
- ✅ 強制遵循 CQRS 模式
- ✅ 避免 Repository 職責膨脹
- ✅ 統一的 Repository 使用方式

### 負面影響
- ⚠️ 需要修改現有違規的程式碼
- ⚠️ 開發者需要適應新的規範
- ⚠️ 無法在 Repository 層級定義領域特定的方法名稱

## 實施方案

### 1. 程式碼修正
```java
// ❌ 錯誤：自定義 Repository 介面
public interface ProductRepository extends Repository<Product, ProductId> {
    // 即使沒有額外方法也不允許
}

// ✅ 正確：直接使用 generic Repository
@Service
public class CreateProductService {
    private final Repository<Product, ProductId> repository;
    
    public CreateProductService(Repository<Product, ProductId> repository) {
        this.repository = repository;
    }
}
```

### 2. 配置修正（Aggregate-Specific 模式）

> ⚠️ **ezapp 2.0.0 更新**：使用 Aggregate-Specific 配置和 Profile Isolation Pattern。
> 參考：`.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/`

```java
// 檔案位置: product/io/springboot/config/ProductUseCaseConfig.java
@Configuration
public class ProductUseCaseConfig {

    // ✅ Profile Isolation Pattern: 直接注入，不需要 @Qualifier
    // Spring 根據 active profile 自動注入正確的 repository bean
    // InMemory 和 Outbox configs 都使用相同的 bean name "productRepository"
    @Bean
    public CreateProductUseCase createProductUseCase(
            Repository<Product, ProductId> productRepository) {
        return new CreateProductService(productRepository);
    }
}
```

### 3. 查詢處理
```java
// 查詢需求使用 Projection
public interface ProductDtoProjection {
    List<ProductDto> findByStatus(String status);
}

// 或使用 JPA Repository（只用於查詢）
@Repository
public interface ProductDataRepository extends JpaRepository<ProductData, String> {
    List<ProductData> findByStatus(String status);
}
```

## 監控與執行

### 自動化檢查
1. **檢查腳本**：`.ai/scripts/check-repository-compliance.sh`
2. **Git Hook**：`.ai/hooks/pre-commit`
3. **AI Prompts**：已更新 command/query sub-agent prompts

### 手動檢查
執行以下命令檢查違規：
```bash
.ai/scripts/check-repository-compliance.sh
```

## 相關文件
- `.ai/tech-stacks/java-ezddd-spring/README.md` - Repository 方法限制
- `.ai/tech-stacks/java-ezddd-spring/CODE-REVIEW-CHECKLIST.md` - 第 768-783 行
- `.ai/tech-stacks/java-ezddd-spring/FAILURE-CASES.md` - 第 127 行
- `CLAUDE.md` - Repository 規範章節

## 修訂歷史
- 2025-08-17：初始決策，發現並修正 ProductBacklogItemRepository 違規
- 2025-08-17：創建自動化檢查工具和 Git hooks
- 2025-08-17：更新 AI prompts 防止未來違規