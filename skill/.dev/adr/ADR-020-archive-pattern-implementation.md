# ADR-020: Archive Pattern 實作規範

## 狀態
接受 (Accepted)

## 上下文
在 CQRS 架構中，我們需要區分 Write Model 和 Read Model 的資料管理機制：
- **Repository Pattern**: 負責 Write Model（Command Side）的聚合根 CRUD 操作
- **Projection Pattern**: 負責 Read Model（Query Side）的資料查詢
- **Archive Pattern**: 負責 Read Model（Query Side）的資料寫入操作

特別是當我們需要管理來自其他 Bounded Context 的參考資料時（如來自 Account BC 的 User 資料），需要一個清晰的模式來處理這些跨 BC 的資料管理需求。

## 決策

### 1. Archive Pattern 定位
- Archive Pattern 專門用於 Query Model 的 CRUD 操作
- 與 Repository（Write Model）和 Projection（Read Model 查詢）形成完整的資料管理體系
- 特別適合管理跨 Bounded Context 的參考資料

### 2. 介面設計規範
```java
// 套件位置：usecase.port.out.archive
package tw.teddysoft.aiscrum.scrumteam.usecase.port.out.archive;

// 繼承 ezddd 框架的 Archive 介面
public interface UserArchive extends Archive<UserData, String> {
    // 只使用繼承的 findById, save, delete 方法
    // 不添加額外的自定義方法
}
```

### 3. 實作規範
```java
// 套件位置：adapter.out.database.springboot.archive
package tw.teddysoft.aiscrum.scrumteam.adapter.out.database.springboot.archive;

// 不加 @Repository 註解
public class JpaUserArchive implements UserArchive {
    private final UserOrmClient userOrmClient;
    
    // 通過建構子注入依賴
    public JpaUserArchive(UserOrmClient userOrmClient) {
        Objects.requireNonNull(userOrmClient, "userOrmClient cannot be null");
        this.userOrmClient = userOrmClient;
    }
    
    // 實作介面方法...
}
```

### 4. Spring Configuration
```java
@Configuration
@Profile({"outbox", "test-outbox"})  // 必須包含 test profile
public class OutboxArchiveConfig {

    @Bean(name = "userArchive")
    public UserArchive userArchive(UserOrmClient userOrmClient) {
        return new JpaUserArchive(userOrmClient);
    }
}
```

### 5. 命名規範
- 介面命名：`XxxArchive`（單數形式）
- 實作命名：`JpaXxxArchive`（JPA 實作）或 `InMemoryXxxArchive`（記憶體實作）
- Bean 名稱：`xxxArchive`（駝峰命名）

## 理由

### 為什麼需要 Archive Pattern？
1. **責任分離**: 清楚區分 Write Model 和 Read Model 的寫入操作
2. **跨 BC 資料管理**: 適合管理來自其他 Bounded Context 的參考資料
3. **簡化介面**: 只提供基本的 CRUD 操作，避免過度設計
4. **框架整合**: 與 ezddd 框架的 Archive 介面完美整合

### 為什麼不用 @Repository 註解？
1. **避免混淆**: @Repository 通常用於 Write Model 的 Repository
2. **明確配置**: 通過 @Bean 明確宣告，更容易管理和測試
3. **Profile 控制**: 可以根據不同 Profile 提供不同實作

## 範例：UserData 管理

### 使用場景
UserData 來自上游 Account BC，在 AiScrum BC 中作為參考資料使用：
- ScrumTeam 需要參考 User 資訊來管理團隊成員
- 使用 Archive Pattern 在本地管理這些參考資料的副本

### 實作範例
```java
// 在應用啟動時初始化測試用戶
private void initializeTestUsers(UserArchive userArchive) {
    String[][] testUsers = {
        {"user-001", "Alice Chen", "alice.chen@example.com"},
        {"user-002", "Bob Wang", "bob.wang@example.com"},
        // ... 更多測試用戶
    };
    
    for (String[] userInfo : testUsers) {
        if (userArchive.findById(userInfo[0]).isEmpty()) {
            UserData userData = new UserData(userInfo[0], userInfo[1], userInfo[2]);
            userArchive.save(userData);
        }
    }
}
```

## 後果

### 正面影響
- 清晰的資料管理架構
- 易於測試和維護
- 符合 CQRS 架構原則
- 支援跨 BC 資料管理

### 負面影響
- 需要額外的配置類別
- 增加一層抽象

## 相關文件
- [Archive 編碼規範](../../.ai/tech-stacks/java-ezddd-spring/coding-standards/archive-standards.md)
- [Repository 規範](../../.ai/tech-stacks/java-ezddd-spring/coding-standards/repository-standards.md)
- [Projection 規範](../../.ai/tech-stacks/java-ezddd-spring/coding-standards/projection-standards.md)