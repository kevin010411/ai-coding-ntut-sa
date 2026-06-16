# JUnit Platform Suite Profile 切換解決方案

## 問題描述
JUnit Platform Suite 無法直接控制 Spring Boot Test 的 profile，因為：
1. Suite 的 static block 不會被執行
2. Spring ApplicationContext 在每個測試類別載入時創建
3. Profile 在 ApplicationContext 初始化時就固定了

## 解決方案（重要發現！）

### 核心概念
利用 JUnit Platform Suite 的 `@SelectClasses` 來指定第一個執行的測試類別，在該測試類別的 static block 中設定 profile。

### 實作步驟

#### 1. 創建 ProfileSetter 測試類別

> ⚠️ **重要**：ProfileSetter **不能有** `@SpringBootTest` 和 `@TestInstance` 註解！
> 參考：ADR-021 和 `.ai/tech-stacks/java-ezddd-spring/checklists/DUAL-PROFILE-TEST-CHECKLIST.md`

**OutboxProfileSetter.java**
```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;

// ⚠️ 注意：不能有 @SpringBootTest、不能有 @TestInstance
public class OutboxProfileSetter {

    static {
        // 關鍵：在 static block 設定 profile
        System.setProperty("spring.profiles.active", "test-outbox");
        System.out.println("OutboxProfileSetter: Set spring.profiles.active=test-outbox");
    }

    @Test
    void setProfile() {
        // 空測試，只是確保 static block 執行
    }
}
```

**InMemoryProfileSetter.java**
```java
package tw.teddysoft.aiscrum.test.suite;

import org.junit.jupiter.api.Test;

// ⚠️ 注意：不能有 @SpringBootTest、不能有 @TestInstance
public class InMemoryProfileSetter {

    static {
        System.setProperty("spring.profiles.active", "test-inmemory");
        System.out.println("InMemoryProfileSetter: Set spring.profiles.active=test-inmemory");
    }

    @Test
    void setProfile() {
        // 空測試，只是確保 static block 執行
    }
}
```

#### 2. 在 TestSuite 中使用 @SelectClasses

**OutboxTestSuite.java**
```java
@Suite
@SuiteDisplayName("Outbox Pattern Tests")
@SelectClasses({
    OutboxProfileSetter.class     // 必須是第一個！
})
@SelectPackages({
    "tw.teddysoft.aiscrum.product",
    "tw.teddysoft.aiscrum.pbi",
    "tw.teddysoft.aiscrum.sprint",
    "tw.teddysoft.aiscrum.scrumteam"
})
public class OutboxTestSuite {
    // Suite 本身的 static block 不會執行，所以不用寫
}
```

**InMemoryTestSuite.java**
```java
@Suite
@SuiteDisplayName("In-Memory Tests")
@SelectClasses({
    InMemoryProfileSetter.class     // 必須是第一個！
})
@SelectPackages({
    "tw.teddysoft.aiscrum.product",
    "tw.teddysoft.aiscrum.pbi",
    "tw.teddysoft.aiscrum.sprint",
    "tw.teddysoft.aiscrum.scrumteam"
})
public class InMemoryTestSuite {
    // Suite 本身的 static block 不會執行，所以不用寫
}
```

## 運作原理

### 執行順序
1. JUnit Platform Suite 開始執行
2. `@SelectClasses` 中的 ProfileSetter 是第一個被載入的測試類別
3. ProfileSetter 的 **static block 執行**，設定 `spring.profiles.active`
4. ProfileSetter 的 Spring ApplicationContext 初始化，讀取到設定的 profile
5. 後續測試類別重用這個 ApplicationContext（Spring Boot Test 的 context caching）
6. 所有測試都使用正確的 profile！

### 為什麼這個方法有效？
- **測試類別的 static block 會執行**（Suite 的不會）
- **第一個測試決定了 ApplicationContext 的 profile**
- **Spring Boot Test 會快取並重用 ApplicationContext**
- **@SelectClasses 保證執行順序**

## 注意事項

1. **ProfileSetter 必須是 @SelectClasses 中的第一個**
2. **不要在 Suite 的 static block 設定 profile**（不會執行）
3. **ProfileSetter 不能有 @SpringBootTest 和 @TestInstance 註解**（會導致 ApplicationContext threshold exceeded）
4. **ProfileSetter 需要至少一個 @Test 方法**（即使是空的）

## 驗證方法

在 BaseUseCaseTest 的 setUpEventCapture() 中加入：
```java
System.out.println("activeProfile = " + activeProfile);
```

執行時應該看到：
- InMemoryTestSuite → `activeProfile = test-inmemory`
- OutboxTestSuite → `activeProfile = test-outbox`

## 總結

這個解決方案巧妙地利用了：
1. JUnit Platform Suite 的執行順序控制
2. 測試類別 static block 的執行時機
3. Spring Boot Test 的 ApplicationContext 快取機制

實現了 **TestSuite 自動切換 Spring Profile** 的需求！

---

**發現者**：使用者透過實驗找到這個解決方案
**記錄日期**：2025-09-01
**重要性**：⭐⭐⭐⭐⭐ 解決了長期困擾的 profile 切換問題