# ADR-049: Profile-Based Testing Architecture

## Status
Accepted

## Context
測試環境需要支援多種執行模式：
- In-memory 模式：快速執行，適合 CI/CD
- Outbox 模式：完整整合測試，使用真實 PostgreSQL

之前多次錯誤地在 `BaseUseCaseTest` 使用 `@ActiveProfiles` 硬編碼 profile，導致無法動態切換測試環境，浪費大量時間除錯。

## Decision
**絕對不要在 BaseUseCaseTest 使用 @ActiveProfiles 註解**

Profile 決定機制：
1. 由 `application-test.yml` 或環境變數決定
2. 支援動態切換，不硬編碼

## Consequences

### Positive
- 測試可以在不同環境執行而不需修改程式碼
- 同一個測試可以驗證 in-memory 和 database 兩種實作
- 開發者可以根據需求選擇執行模式

### Negative
- 需要明確設定環境變數或依賴預設配置
- 可能造成混淆如果不清楚 profile 來源

## Implementation

### ❌ 錯誤做法（絕對禁止）
```java
@ActiveProfiles("test-inmemory")  // ❌ 不要硬編碼！
public abstract class BaseUseCaseTest extends BaseSpringBootTest {
}
```

### ✅ 正確做法
```java
// 不加任何 profile 註解
public abstract class BaseUseCaseTest extends BaseSpringBootTest {
    // 讓 application-test.yml 或環境變數決定
}

// 測試類別需要 @DirtiesContext 確保測試隔離
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)
public class CreateProductServiceTest extends BaseUseCaseTest {
    @BeforeEach
    void setUp() {
        DateProvider.useSystemTime();
        // ⛔ 不要呼叫 setUpEventCapture() - 父類別的 @BeforeEach 已經呼叫
    }
    // ⛔ 不需要 @AfterEach - 父類別的 @AfterEach 已經處理 relay 清理
}
```

### @DirtiesContext 必須使用 BEFORE_EACH_TEST_METHOD

**為什麼？**
- `EzesVolatileRelay` 是有狀態的 Runnable，`shutdownNow()` 後 `running` 旗標變 `false`
- 重複執行 `executor.execute(relay)` 無效（relay 不再運行）
- `BEFORE_EACH_TEST_METHOD` 確保每個測試方法有乾淨的 Spring Context

**典型失敗症狀**：
- 第一個測試通過，後續測試失敗
- 事件驗證超時
- `expected: <1> but was: <0>` 或 `expected: <1> but was: <9>`

詳見：`.dev/lessons/EZES-VOLATILE-RELAY-SINGLETON-TRAP.md`

### Profile 來源優先順序
1. **環境變數**: `SPRING_PROFILES_ACTIVE=test-outbox`
2. **配置檔案**: `application-test.yml` 中的 `spring.profiles.active: ${SPRING_PROFILES_ACTIVE:test-inmemory}`
3. **測試套件**: 透過 ProfileSetter 類別的 static block（必須是 @SelectClasses 的第一個類別）
   - 詳見 `.dev/lessons/JUNIT-SUITE-PROFILE-SWITCHING.md`
   - ⚠️ 注意：TestSuite 本身的 static block 不會執行！

### 執行範例
```bash
# 使用 in-memory profile（預設）
mvn test -Dtest=GetProductUseCaseTest

# 使用 outbox profile（PostgreSQL）
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest=GetProductUseCaseTest
```

## References
- 相關討論：多次因為硬編碼 profile 導致測試無法切換環境
- 參考文件：Spring Boot Testing Documentation
- 錯誤案例：2025-08-30 又一次在 BaseUseCaseTest 加了 @ActiveProfiles

## Lessons Learned
🔴 **重要教訓**：已經在這個問題上犯錯太多次！
- 每次看到 `BaseUseCaseTest` 就要檢查有沒有 `@ActiveProfiles`
- Profile 應該是可配置的，不是硬編碼的
- 動態 > 靜態，配置 > 程式碼

## Notes
這個 ADR 的存在本身就是一個警告 - 我們已經在同一個問題上浪費太多時間了。

## Updates
- 2025-09-01: 發現 TestSuite Profile 切換的正確方法（見 `.dev/lessons/JUNIT-SUITE-PROFILE-SWITCHING.md`）
  - TestSuite 的 static block 不會執行
  - 必須使用 ProfileSetter 類別作為 @SelectClasses 的第一個類別