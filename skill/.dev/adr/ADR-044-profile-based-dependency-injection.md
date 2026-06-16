# ADR-044: Profile-Based Dependency Injection 規範

## Status
Accepted

## Date
2025-09-07

## Context
在實作 InMemory 和 Outbox Profile 雙軌架構時，發現 TestDataInitializer 強制依賴 JdbcTemplate，導致 InMemory Profile 無法啟動。這暴露了一個設計問題：不同 Profile 有不同的基礎設施依賴。

## Decision
我們決定建立以下規範來防止 Profile 依賴衝突：

### 1. 條件化依賴注入
```java
// ✅ 正確：使用 @Autowired(required = false)
@Autowired(required = false)
private JdbcTemplate jdbcTemplate;

// ❌ 錯誤：強制依賴
@Autowired
private JdbcTemplate jdbcTemplate;
```

### 2. Bean 方法不應有 Profile 特定參數
```java
// ✅ 正確：無參數或通用參數
@Bean
public CommandLineRunner initTestData() {
    return args -> { ... };
}

// ❌ 錯誤：依賴特定 Profile 的元件
@Bean
public CommandLineRunner initTestData(JdbcTemplate jdbcTemplate) {
    return args -> { ... };
}
```

### 3. Runtime 檢查依賴可用性
```java
// ✅ 正確：檢查依賴是否可用
private void cleanDatabase() {
    if (jdbcTemplate == null) {
        log.info("JdbcTemplate not available, skipping database cleanup");
        return;
    }
    // 執行資料庫操作
}

// ❌ 錯誤：直接使用可能為 null 的依賴
private void cleanDatabase() {
    jdbcTemplate.execute("DELETE FROM ...");  // NPE 風險！
}
```

### 4. Profile 配置檔案必須明確排除不需要的自動配置
```properties
# application-inmemory.properties
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
```

## Consequences

### Positive
- ✅ 不同 Profile 可以獨立運行，不會互相干擾
- ✅ 減少不必要的依賴，提高啟動速度
- ✅ 更容易測試和除錯
- ✅ 架構更有彈性，容易新增新的 Profile

### Negative
- ❌ 需要更多 null 檢查程式碼
- ❌ 開發者需要了解不同 Profile 的依賴差異
- ❌ 可能增加配置複雜度

## Implementation Checklist

### 新增 Profile 時必須：
1. ☑️ 創建對應的 `application-{profile}.properties`
2. ☑️ 明確定義需要排除的自動配置
3. ☑️ 檢查所有 @Autowired 是否需要 `required = false`
4. ☑️ 確認 @Bean 方法不依賴 Profile 特定元件
5. ☑️ 加入 null 檢查防護

## Testing Strategy

### Profile 啟動測試腳本
```bash
#!/bin/bash
# test-profile-startup.sh

echo "Testing InMemory Profile..."
SPRING_PROFILES_ACTIVE=test-inmemory mvn spring-boot:run &
PID=$!
sleep 10
if ps -p $PID > /dev/null; then
    echo "✅ InMemory Profile started successfully"
    kill $PID
else
    echo "❌ InMemory Profile failed to start"
    exit 1
fi

echo "Testing Outbox Profile..."
SPRING_PROFILES_ACTIVE=test-outbox mvn spring-boot:run &
PID=$!
sleep 10
if ps -p $PID > /dev/null; then
    echo "✅ Outbox Profile started successfully"
    kill $PID
else
    echo "❌ Outbox Profile failed to start"
    exit 1
fi
```

## References
- Spring Boot Profile Documentation
- ADR-021: Profile-Based Testing Architecture
- ADR-019: Outbox Pattern 實作規範