# ADR-021: Spring Profile 配置檔案載入機制

## 狀態
已採用 (Adopted)

## 日期
2025-08-26

## 背景 (Context)
在實作 Outbox Pattern 測試時，需要使用不同的資料庫配置（PostgreSQL 而非 H2）。Spring Boot 的 Profile 機制允許我們為不同環境載入不同的配置檔案，但團隊需要了解 `@ActiveProfiles` 如何決定載入哪個配置檔案。

## 決策 (Decision)
採用 Spring Boot 標準的 Profile 命名規則來組織配置檔案，並使用 `@ActiveProfiles` 註解來啟用特定的 Profile。

## 詳細說明

### 1. 配置檔案命名規則
Spring Boot 會自動尋找符合以下命名模式的檔案：
- `application-{profile}.properties`
- `application-{profile}.yml`
- `application-{profile}.yaml`

範例：當使用 `@ActiveProfiles("test-outbox")` 時，Spring Boot 會尋找：
- `application-test-outbox.yml`（或 .properties/.yaml）

### 2. 檔案搜尋位置與優先順序

```
專案結構：
├── src/test/resources/        # 測試環境（優先）
│   ├── application.properties
│   ├── application-test.properties
│   └── application-test-outbox.yml
└── src/main/resources/        # 主程式環境
    ├── application.properties
    └── application-{profile}.yml
```

搜尋優先順序（由高到低）：
1. `src/test/resources/`（測試執行時）
2. `src/main/resources/`（一般執行時）

### 3. 配置載入流程

當測試類別使用 `@ActiveProfiles("test-outbox")` 時：

```java
@SpringBootTest
@ActiveProfiles("test-outbox")
public class ProductOutboxRepositoryTest {
    // 測試程式碼
}
```

Spring Boot 執行步驟：
1. **載入基礎配置**：`application.properties` 或 `application.yml`
2. **載入 Profile 配置**：`application-test-outbox.yml`
3. **配置覆蓋**：Profile 配置會覆蓋基礎配置中的相同屬性

### 4. 實際應用範例

#### 基礎配置 (`application.properties`)
```properties
# 預設配置
server.port=8080
# 預設使用 InMemory Repository，不需要資料庫配置
```

#### Profile 配置 (`application-test-outbox.yml`)
```yaml
# Outbox 測試專用配置
spring:
  datasource:
    url: jdbc:postgresql://localhost:5800/board?currentSchema=message_store  # 覆蓋
    username: postgres    # 新增
    password: root        # 新增
    driver-class-name: org.postgresql.Driver  # 覆蓋

# 使用變數引用避免重複
messagestore:
  postgres:
    url: ${spring.datasource.url}
    user: ${spring.datasource.username}
    password: ${spring.datasource.password}

# server.port 仍為 8080（未被覆蓋）
```

### 5. 多重 Profile 配置

可以同時啟用多個 Profile：

```java
@ActiveProfiles({"test", "outbox"})
public class IntegrationTest {
    // Spring Boot 會依序載入：
    // 1. application.properties
    // 2. application-test.properties
    // 3. application-outbox.properties
}
```

載入順序：後面的配置會覆蓋前面的相同屬性。

### 6. Profile 配置策略

本專案採用的 Profile 策略：

| Profile | 用途 | 配置檔案 | 主要配置 |
|---------|------|----------|----------|
| `default` | 單元測試 | `application.properties` | InMemory Repository |
| `test` | 整合測試 | `application-test.properties` | PostgreSQL 測試資料庫 |
| `test-outbox` | Outbox 測試 | `application-test-outbox.yml` | PostgreSQL + Message Store |
| `outbox` | Outbox 模式 | `application-outbox.properties` | PostgreSQL + Outbox Pattern |
| `dev` | 開發環境 | `application-dev.yml` | 本地 PostgreSQL |
| `prod` | 生產環境 | `application-prod.yml` | 生產 PostgreSQL |

### 7. 驗證配置載入

可以透過以下方式驗證配置是否正確載入：

```java
@SpringBootTest
@ActiveProfiles("test-outbox")
public class ProfileVerificationTest {
    
    @Autowired
    private Environment env;
    
    @Value("${spring.datasource.url}")
    private String datasourceUrl;
    
    @Test
    public void should_load_correct_profile() {
        // 驗證 Profile 已啟用
        assertThat(env.getActiveProfiles()).contains("test-outbox");
        
        // 驗證配置已載入
        assertThat(datasourceUrl).contains("localhost:5800");
        assertThat(env.getProperty("spring.datasource.driver-class-name"))
            .isEqualTo("org.postgresql.Driver");
    }
}
```

### 8. 最佳實踐

1. **命名一致性**：使用連字號分隔 Profile 名稱（如 `test-outbox`，而非 `testOutbox`）
2. **配置分離**：將環境特定配置放在 Profile 檔案中，共用配置放在基礎檔案
3. **變數引用**：使用 `${property.name}` 避免配置重複
4. **文件化**：在 README 或配置檔案中註釋每個 Profile 的用途
5. **測試隔離**：測試專用 Profile 應該在 `src/test/resources/` 目錄下

## 效益 (Consequences)

### 優點
- ✅ **環境隔離**：不同環境使用不同配置，避免混淆
- ✅ **配置重用**：透過繼承和覆蓋機制減少重複
- ✅ **測試彈性**：可以為不同測試場景準備專門配置
- ✅ **部署簡化**：同一個 JAR 檔可以透過 Profile 適應不同環境

### 缺點
- ⚠️ **配置分散**：需要查看多個檔案才能了解完整配置
- ⚠️ **覆蓋風險**：可能不小心覆蓋重要配置
- ⚠️ **除錯困難**：需要確認哪個 Profile 被啟用、哪個配置生效

## ⚠️ 重要限制：測試中禁止使用 @ActiveProfiles

> **根據 ADR-021 決策，禁止在測試類別中使用 `@ActiveProfiles` 註解。**

本 ADR 說明的是 Spring Profile 機制的**工作原理**，但在實際測試中：

### ❌ 禁止做法
```java
@SpringBootTest
@ActiveProfiles("test-outbox")  // ❌ 禁止！
public class SomeTest { }
```

### ✅ 正確做法

**方法 1：使用 TestSuite 的 ProfileSetter（推薦）**
```java
@Suite
@SelectClasses({
    OutboxProfileSetter.class,  // 必須是第一個！
    YourServiceTest.class
})
public class OutboxTestSuite { }

// ProfileSetter 設定 profile
@SpringBootTest
public class OutboxProfileSetter {
    static {
        System.setProperty("spring.profiles.active", "test-outbox");
    }
    @Test void setProfile() { }
}
```

**方法 2：使用環境變數**
```bash
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest=YourTest
```

詳見：
- ADR-021: Profile-Based Testing Architecture
- `.dev/lessons/JUNIT-SUITE-PROFILE-SWITCHING.md`

## 相關文件
- [Spring Boot Profile 官方文件](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.profiles)
- [ADR-019: Outbox Pattern Implementation](./ADR-019-outbox-pattern-implementation.md)
- [Outbox 測試配置指南](.ai/tech-stacks/java-ezddd-spring/examples/outbox/OUTBOX-TEST-CONFIGURATION.md)

## 修訂歷史
- 2025-08-26：初始版本，記錄 Spring Profile 配置載入機制