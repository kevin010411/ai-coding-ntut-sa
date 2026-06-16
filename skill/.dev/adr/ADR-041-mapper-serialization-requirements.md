# ADR-022: Mapper Serialization Requirements

## Status
Accepted

## Context
在實作 `ProductMapper` 時發現了幾個關鍵問題：
1. Jackson ObjectMapper 預設無法序列化 Java 8 時間類型（如 `Instant`）
2. `toDomain()` 方法需要正確還原所有複雜物件（如 `DefinitionOfDone`）
3. 序列化失敗時應該妥善處理，不應該中斷整個流程

### 問題案例
```java
// 錯誤：預設 ObjectMapper 無法處理 Instant
private static final ObjectMapper objectMapper = new ObjectMapper();

// 錯誤：toDomain() 沒有還原 DefinitionOfDone
public static Product toDomain(ProductData productData) {
    // ... 創建 Product
    // 遺漏了 DefinitionOfDone 的還原
    return product;
}
```

## Decision

### 1. ObjectMapper 配置規範
所有 Mapper 類別必須正確配置 ObjectMapper：

```java
private static final ObjectMapper objectMapper = createObjectMapper();

private static ObjectMapper createObjectMapper() {
    ObjectMapper mapper = new ObjectMapper();
    mapper.registerModule(new JavaTimeModule());
    // 其他必要的配置
    return mapper;
}
```

### 2. toData() 方法實作規範
- 必須處理所有複雜物件的序列化
- 序列化失敗時應該優雅降級，不拋出異常
- 必須包含 domain events 和時間戳記

```java
public static ProductData toData(Product product) {
    // 1. 基本欄位映射
    productData.setProductId(product.getId().value());
    
    // 2. 複雜物件序列化為 JSON
    if (product.getDefinitionOfDone() != null) {
        try {
            productData.setDefinitionOfDone(
                objectMapper.writeValueAsString(product.getDefinitionOfDone())
            );
        } catch (Exception e) {
            // 優雅降級，不中斷流程
            productData.setDefinitionOfDone(null);
        }
    }
    
    // 3. Domain events 和 metadata
    productData.setDomainEventDatas(/*...*/);
    productData.setStreamName(/*...*/);
    
    return productData;
}
```

### 3. toDomain() 方法實作規範
- 優先從 domain events 重建（Event Sourcing）
- 若無 events，從當前狀態重建
- 必須還原所有複雜物件

```java
public static Product toDomain(ProductData productData) {
    // 優先從 events 重建
    if (productData.getDomainEventDatas() != null && !productData.getDomainEventDatas().isEmpty()) {
        // Event sourcing 重建
        return new Product(domainEvents);
    }
    
    // 從當前狀態重建
    Product product = new Product(/*...*/);
    
    // 還原複雜物件
    if (productData.getDefinitionOfDone() != null) {
        try {
            DefinitionOfDone dod = objectMapper.readValue(
                productData.getDefinitionOfDone(), 
                DefinitionOfDone.class
            );
            product.defineDefinitionOfDone(
                dod.name(),
                dod.criteria(),
                dod.note(),
                dod.definedAt()
            );
        } catch (Exception e) {
            // 優雅降級
        }
    }
    
    return product;
}
```

### 4. Mapper 類別結構規範
```java
public class [Aggregate]Mapper {
    // 1. 必要的依賴
    private static final ObjectMapper objectMapper = createObjectMapper();
    private static final OutboxMapper<[Aggregate], [Aggregate]Data> outboxMapper = new Mapper();
    
    // 2. DTO 轉換方法（用於 API 層）
    public ProductDto toDto(Product product) { }
    public static ProductDto toDto(ProductData data) { }
    
    // 3. Domain/Data 轉換方法（用於持久層）
    public static ProductData toData(Product aggregate) { }
    public static Product toDomain(ProductData data) { }
    
    // 4. OutboxMapper 支援
    public static OutboxMapper<Product, ProductData> newMapper() { }
    
    // 5. 內部 OutboxMapper 實作
    static class Mapper implements OutboxMapper<Product, ProductData> { }
}
```

## Consequences

### 正面影響
1. **正確的序列化支援**：支援所有 Java 8+ 時間類型
2. **完整的資料還原**：確保 domain 物件的完整性
3. **優雅的錯誤處理**：序列化失敗不會導致系統崩潰
4. **支援 Event Sourcing**：可從事件或當前狀態重建

### 負面影響
1. **額外的複雜度**：需要處理序列化/反序列化錯誤
2. **性能考量**：JSON 序列化有一定的效能開銷

## Implementation Checklist
- [ ] 配置 ObjectMapper 支援 JavaTimeModule
- [ ] toData() 方法處理所有複雜物件
- [ ] toDomain() 方法完整還原所有欄位
- [ ] 實作 OutboxMapper 內部類別
- [ ] 加入適當的錯誤處理

## Related
- ADR-019: Outbox Pattern Implementation
- ADR-020: Archive Pattern Implementation  
- `.ai/tech-stacks/java-ezddd-spring/coding-standards/mapper-standards.md`

## Date
2025-08-24