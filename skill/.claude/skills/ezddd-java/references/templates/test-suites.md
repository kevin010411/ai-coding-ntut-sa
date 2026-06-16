# Test Suite Templates — Global TestSuite with @SelectPackages

> **Canonical Pattern**: 全專案只有兩個 TestSuite（`InMemoryTestSuite` + `OutboxTestSuite`），
> 使用 `@SelectPackages` 按 aggregate package 自動掃描測試類別。
>
> **完整參考**：`references/examples/dual-profile-test-infrastructure.md` Section 9 — 設計決策、命名慣例、何時產生。

## 🚨 重要規則

1. **全專案只有兩個 TestSuite** — `InMemoryTestSuite` + `OutboxTestSuite`，不要產生 per-use-case suite
2. **使用 `@SelectPackages`** — 按 aggregate package 自動掃描測試類別
3. **使用 `@ExcludeClassNamePatterns(".*ControllerTest")`** — 排除 Controller 測試
4. **`@SelectClasses` 只放 `ProfileSetter.class`** — 測試類別由 `@SelectPackages` 掃描，不手動列舉
5. **不使用 standalone ProfileSetter 檔案** — ProfileSetter 是 TestSuite 的 inner class
6. **新增 Aggregate 時** — 在兩個 TestSuite 的 `@SelectPackages` 加入新的 aggregate package

---

## 1. InMemoryTestSuite — 全域模板

**完整路徑**: `src/test/java/${rootPackage}/test/suite/InMemoryTestSuite.java`

```java
package ${rootPackage}.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("In-Memory Tests - Fast Execution")
@SelectClasses({
        InMemoryTestSuite.ProfileSetter.class
})
@SelectPackages({
        // 每個 aggregate 一行，新增 aggregate 時在此加入
        "${rootPackage}.${aggregate1}",
        "${rootPackage}.${aggregate2}"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class InMemoryTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-inmemory");
            System.setProperty("spring.autoconfigure.exclude",
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                            "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration");
        }

        @Test
        void setProfile() {
        }
    }
}
```

## 2. OutboxTestSuite — 全域模板

**完整路徑**: `src/test/java/${rootPackage}/test/suite/OutboxTestSuite.java`

```java
package ${rootPackage}.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("Outbox Pattern Tests - PostgreSQL Database")
@SelectClasses({
        OutboxTestSuite.ProfileSetter.class
})
@SelectPackages({
        // 每個 aggregate 一行，新增 aggregate 時在此加入
        "${rootPackage}.${aggregate1}",
        "${rootPackage}.${aggregate2}"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class OutboxTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-outbox");
            System.setProperty("spring.datasource.url", "${datasourceUrl}");
            System.setProperty("spring.datasource.username", "${datasourceUsername}");
            System.setProperty("spring.datasource.password", "${datasourcePassword}");
            System.setProperty("spring.jpa.hibernate.ddl-auto", "update");
            System.setProperty("spring.jpa.properties.hibernate.default_schema", "${schema}");
        }

        @Test
        void setProfile() {
        }
    }
}
```

## 3. 具體範例（from working code）

### InMemoryTestSuite

```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("In-Memory Tests - Fast Execution")
@SelectClasses({
        InMemoryTestSuite.ProfileSetter.class
})
@SelectPackages({
        "tw.teddysoft.aiscrum.pbi",
        "tw.teddysoft.aiscrum.product",
        "tw.teddysoft.aiscrum.scrumteam",
        "tw.teddysoft.aiscrum.sprint",
        "tw.teddysoft.aiscrum.workflow"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class InMemoryTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-inmemory");
            System.setProperty("spring.autoconfigure.exclude",
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                            "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration");
        }

        @Test
        void setProfile() {
        }
    }
}
```

### OutboxTestSuite

```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.ExcludeClassNamePatterns;
import org.junit.platform.suite.api.SelectClasses;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;
import org.junit.platform.suite.api.SuiteDisplayName;
import org.springframework.boot.test.context.SpringBootTest;

@Suite
@SuiteDisplayName("Outbox Pattern Tests - PostgreSQL Database")
@SelectClasses({
        OutboxTestSuite.ProfileSetter.class
})
@SelectPackages({
        "tw.teddysoft.aiscrum.pbi",
        "tw.teddysoft.aiscrum.product",
        "tw.teddysoft.aiscrum.scrumteam",
        "tw.teddysoft.aiscrum.sprint"
})
@ExcludeClassNamePatterns(".*ControllerTest")
public class OutboxTestSuite {

    @SpringBootTest
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-outbox");
            System.setProperty("spring.datasource.url", "jdbc:postgresql://localhost:${dbPort}/${dbName}?currentSchema=message_store");
            System.setProperty("spring.datasource.username", "postgres");
            System.setProperty("spring.datasource.password", "root");
            System.setProperty("spring.jpa.hibernate.ddl-auto", "update");
            System.setProperty("spring.jpa.properties.hibernate.default_schema", "message_store");
        }

        @Test
        void setProfile() {
        }
    }
}
```

---

## 使用說明

### ProfileSetter Inner Class 的作用
- **必須是 `@SelectClasses` 中唯一的類別** — 測試類別由 `@SelectPackages` 自動掃描
- 透過 static block 在類別載入時設定 `spring.profiles.active` 及其他必要屬性
- 確保在 Spring context 初始化前設定正確的 profile
- 包含空的 `@Test` 方法確保 static block 執行

### InMemory ProfileSetter 特殊設定
- 排除 `DataSourceAutoConfiguration` 和 `HibernateJpaAutoConfiguration`
- 避免 Spring 嘗試建立 JDBC 連線（InMemory 不需要資料庫）

### Outbox ProfileSetter 特殊設定
- 設定 PostgreSQL 連線資訊（URL、username、password）
- 設定 `ddl-auto = update`（保持 messages table 結構）
- 設定 `default_schema`

### @SelectPackages 掃描規則
- 掃描指定 package 及所有子 package 中的測試類別
- `@ExcludeClassNamePatterns(".*ControllerTest")` 排除 Controller 測試
- 新增 Aggregate 時，只需在 `@SelectPackages` 加入該 aggregate 的 root package

### Profile 切換機制優先順序
1. Test Suite 的 ProfileSetter（最高優先）
2. 環境變數 `SPRING_PROFILES_ACTIVE`
3. Maven profile 設定

### 與 BaseUseCaseTest 的關係
- Test Suite 設定 profile
- BaseUseCaseTest 偵測 profile 並調整行為（如 outbox 的 stale event drain）
- 測試類別不需要知道 profile 細節

### ⚠️ 絕對不要
- 在測試類別上使用 `@ActiveProfiles`
- 在 `BaseUseCaseTest` 上使用 `@ActiveProfiles`
- 建立 **per-use-case TestSuite**（如 `InMemoryCreateProductTestSuite`）— 只允許全域 TestSuite
- 建立獨立的 `InMemoryProfileSetter.java` 或 `OutboxProfileSetter.java` 檔案

### ✅ 應該要
- 使用 inner class ProfileSetter
- 使用 `@SelectPackages` 自動掃描（不手動列舉測試類別）
- 全專案只有兩個 TestSuite：`InMemoryTestSuite` + `OutboxTestSuite`
- 新增 Aggregate 時更新 `@SelectPackages`

### 何時產生 / 更新 TestSuite

| 時機 | 動作 |
|------|------|
| **init-project** | **不產生** TestSuite（尚無 aggregate，等第一次 PF 執行） |
| **第一次 PF 執行** | 建立 `InMemoryTestSuite` + `OutboxTestSuite`，`@SelectPackages` 加入第一個 aggregate package |
| **後續 PF 執行（同一 Aggregate）** | 不需修改 TestSuite（`@SelectPackages` 已包含該 package） |
| **後續 PF 執行（新 Aggregate）** | 在兩個 TestSuite 的 `@SelectPackages` 加入新 aggregate package |

## 佔位符說明
- `${rootPackage}`: 從 `.dev/project-config.json` 取得
- `${aggregate1}`, `${aggregate2}`: Aggregate 名稱（小寫，如 `product`、`sprint`）
- `${datasourceUrl}`: PostgreSQL 連線 URL
- `${datasourceUsername}`: 資料庫使用者名稱
- `${datasourcePassword}`: 資料庫密碼
- `${schema}`: 資料庫 schema 名稱
