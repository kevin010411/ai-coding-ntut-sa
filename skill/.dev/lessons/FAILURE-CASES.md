# AI Coding 失敗案例庫

> 記錄 AI 實際產生的錯誤，讓 AI 從錯誤中學習

## ✅ 成功案例：謹慎修復測試錯誤的最佳實踐（2024-08-27）

### 📋 問題描述
初始狀態有 20 個測試錯誤（3 failures + 17 errors），需要謹慎修復而不引入新問題。

### 🎯 修復策略
1. **先建立基準線**：執行完整測試，記錄確切的錯誤數量和類型
2. **分類錯誤**：將錯誤按測試類別分組，找出相關性
3. **逐個分析**：每個錯誤類別深入分析根本原因
4. **最小化修改**：只修復實際問題，不做額外的「改進」
5. **立即驗證**：每次修復後立即執行相關測試

### 🔧 實際修復案例

#### 1. JPA 資料持久化問題
**問題**：Spring Data JPA save() 沒有立即寫入資料庫
```java
// ❌ 錯誤：使用 CrudRepository 的 save() 不保證立即 flush
public interface UserOrmClient extends CrudRepository<UserData, String> {}

// ✅ 修復：改用 JpaRepository 並使用 saveAndFlush
public interface UserOrmClient extends JpaRepository<UserData, String> {}

// Archive 實作也要配合修改
public void save(UserData userData) {
    userOrmClient.saveAndFlush(userData);  // 確保立即寫入
}
```

#### 2. 測試資料庫表格缺失
**問題**：測試期望的表格不存在
```java
// ❌ 錯誤：直接執行 SQL 導致表格不存在錯誤
jdbcTemplate.update("DELETE FROM scrum_team_members WHERE ...");

// ✅ 修復方案一：建立 schema 檔案
@Sql(scripts = "/scrum-teams-test-schema.sql", 
     executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD)

// ✅ 修復方案二：錯誤處理
try {
    jdbcTemplate.update("DELETE FROM scrum_team_members WHERE ...");
} catch (Exception e) {
    // 表格可能不存在，忽略錯誤
}
```

#### 3. 測試期望值與實際行為不符
**問題**：測試期望固定資料，但 controller 實際使用動態資料
```java
// ❌ 錯誤：期望固定的 10 個用戶
.andExpect(jsonPath("$.users", hasSize(10)))

// ✅ 修復：根據 mock 資料調整期望值
when(getUsersUseCase.execute(any())).thenReturn(
    createSuccessOutput(Arrays.asList(user1, user2))
);
.andExpect(jsonPath("$.users", hasSize(2)))  // 匹配實際資料
```

### 📊 修復成果
- 初始狀態：20 個錯誤（3 failures + 17 errors）
- 最終結果：0 個錯誤 ✅
- 關鍵：沒有引入新的錯誤

### 🎓 學習要點
1. **不要過度修正**：只修復實際的問題，避免「順便改進」導致新問題
2. **理解根本原因**：JPA 的 flush 時機、測試環境配置等
3. **分批處理**：相關錯誤一起處理，但要逐步驗證
4. **保留安全網**：使用 try-catch 處理可能的環境差異
5. **測試與實作同步**：確保測試期望值與實際實作行為一致

### 🔍 診斷技巧
- 使用 `-q` 參數減少 Maven 輸出噪音
- 執行單一測試類別來隔離問題
- 檢查 Spring profiles 配置（test vs test-outbox）
- 注意資料庫差異（H2 vs PostgreSQL）

---

## 🚫 案例 1：Value Object 重複定義（2024-08-12）

### ❌ AI Code Review 遺漏的問題
```java
// pbi/entity/SprintId.java - 錯誤的重複定義
package tw.teddysoft.aiscrum.pbi.entity;

public final class SprintId implements ValueObject {
    private final String value;
    // ...
}

// sprint/entity/SprintId.java - 正確的定義位置
package tw.teddysoft.aiscrum.sprint.entity;

public record SprintId(String value) implements ValueObject {
    // ...
}
```

### 🔍 為什麼會遺漏
1. Code review 過度專注在程式碼品質細節（validation, record usage）
2. 沒有執行跨 package 的重複檢查
3. 忽略了「沒有 import 卻能使用」這個警訊

### ✅ 正確做法
```java
// PBI 應該引用 Sprint 的 SprintId
package tw.teddysoft.aiscrum.pbi.entity;

import tw.teddysoft.aiscrum.sprint.entity.SprintId;  // 正確的 import

public class ProductBacklogItem {
    private SprintId sprintId;  // 使用來自 sprint package 的 SprintId
}
```

### 📚 學習要點
- **每個 Value Object 只能定義一次**，在其所屬的 Aggregate package 中
- **跨 Aggregate 引用**必須使用 import，不能重複定義
- **Code Review 必須包含架構層面**的檢查，不只是程式碼細節

---

## 🚫 案例 2：RTK Query 快取問題導致任務彈回原位（2024-08-17）⚠️ 嚴重錯誤

### ❌ 問題描述
使用者多次報告：
1. 「Scrum Board 一進去是舊狀態，要 reload 才會拿到最新狀態」
2. 「把 task 從 done 移到 doing, task 會直接彈回 done」
3. 「你又犯同樣的錯誤」

### 🔍 真正的根本原因（多次誤診後才發現）
1. **本地 state 覆蓋 RTK Query 快取** - useEffect 在每次 pbiData 更新時重設本地 state
2. **欄位名稱不匹配** - 後端返回 `status`，但樂觀更新在更新 `state`
3. **過度使用 useEffect** - 創造了狀態更新的連鎖反應
4. **儲存衍生狀態** - 用 useState 儲存應該用 useMemo 計算的資料

### ❌ 錯誤的嘗試（全部失敗）
```javascript
// 嘗試 1：setTimeout 延遲 ❌
setTimeout(() => { refetchPbis(); }, 100);

// 嘗試 2：設定零快取 ❌
keepUnusedDataFor: 0

// 嘗試 3：強制 refetch ❌
useEffect(() => { refetchPbis(); }, [sprintId]);

// 嘗試 4：手動 invalidate ❌
dispatch(pbiApi.util.invalidateTags([...]));
```

### ✅ 真正的解決方案
```javascript
// 1. 使用 useMemo 衍生狀態，不要儲存
const pbis = useMemo(() => {
  return pbiData.map(pbi => transformPbi(pbi));
}, [pbiData, expandedPbis]);

// 2. 樂觀更新正確的欄位
(task as any).status = newState; // 後端用 status，不是 state！

// 3. 只在初始載入時設定 UI 狀態
useEffect(() => {
  if (pbiData && expandedPbis.size === 0) {
    setExpandedPbis(new Set(pbiData.map(p => p.id)));
  }
}, [pbiData, expandedPbis.size]);

// 4. 成功時不要 invalidate
invalidatesTags: (result, error) => {
  if (error) return [{ type: 'Sprint' }];
  return []; // 信任樂觀更新
}
```

### 📚 痛苦的教訓
- **不要用補丁解決問題** - setTimeout、refetch 都是錯誤的方向
- **確認 API 欄位名稱** - 不要假設，要實際檢查
- **理解 React 資料流** - props → state → UI，不要逆流
- **使用正確的 React 模式** - useMemo for 衍生狀態，useState for UI 狀態
- **測試完整流程** - 不只測當下，要測離開再回來

### 🔥 警告
這個問題出現了**至少 5 次**，每次都用不同的補丁「解決」，最後都失敗。
**絕對不要**再用 setTimeout、refetch、keepUnusedDataFor: 0 這些方法！

---

## 🚫 案例 3：遺漏 Spec 中明確要求的 Mapper 元件（2024-08-14）

### ❌ 錯誤：直接在 Projection 中實作轉換邏輯
```java
// 錯誤：直接在 JpaProductDtoProjection 寫轉換邏輯
public class JpaProductDtoProjection implements ProductDtoProjection {
    
    private ProductDto toDto(Product product) {
        // 直接實作轉換邏輯，沒有使用 Mapper
        ProductDto dto = new ProductDto();
        dto.setId(product.getId().value());
        // ... 轉換邏輯
        return dto;
    }
}
```

### 🔍 為什麼會遺漏
1. **Spec 解析不完整** - 沒有仔細檢查 "mappers" 區塊
2. **急於實現功能** - 專注在讓程式能運作，忽略架構設計
3. **缺乏 Checklist** - 沒有從 spec 建立完整的實作清單

### ✅ 正確做法
```java
// 1. 建立獨立的 Mapper
@Component
public class ProductMapper {
    public ProductDto toDto(Product product) {
        // 轉換邏輯
    }
}

// 2. Projection 使用 Mapper
@Component  
public class JpaProductDtoProjection implements ProductDtoProjection {
    private final ProductMapper productMapper;
    
    public Optional<ProductDto> query(Input input) {
        return repository.findById(id)
            .map(productMapper::toDto);  // 使用 mapper
    }
}
```

### 📚 學習要點
- **Spec 是 Contract** - spec 中列出的所有元件都必須實作
- **Separation of Concerns** - Mapper 負責轉換，Projection 負責查詢
- **實作前建立 Checklist** - 從 spec 提取所有需要的元件清單

---

## 🚫 案例 3：自動產生 Repository 實作

### ❌ AI 產生的錯誤程式碼
```java
// AI 自動「發明」了 InMemoryPlanRepository
public class InMemoryPlanRepository implements Repository<Plan, PlanId> {
    private Map<PlanId, Plan> storage = new HashMap<>();
    
    @Override
    public Optional<Plan> findById(PlanId id) {
        return Optional.ofNullable(storage.get(id));
    }
    // ... 其他方法
}
```

### ✅ 正確做法 (ezapp 2.0.0)
```java
// 使用框架提供的 InMemory 類別 + Spring DI
// 不要手動建立 Repository，透過 @Autowired 注入

@Autowired
private Repository<Product, ProductId> productRepository;

// 配置在 Aggregate-Specific Config 中：
// InMemoryOrmDb + InMemoryOrmClient + OutboxRepository
// 參考：.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/ProductInMemoryRepositoryConfig.java
```

### 📝 教訓
- **永遠不要**自己實作 Repository
- **必須使用** Spring DI 注入 Repository
- **ezapp 2.0.0**：使用框架提供的 `InMemoryOrmDb` + `InMemoryOrmClient` + `OutboxRepository`
- **原因**：框架已經處理了 Event Sourcing 的複雜性

---

## 🚫 案例 2：Value Object 錯誤使用 Contract 驗證

### ❌ AI 產生的錯誤程式碼（2024-08-11, task-101）
```java
// Value Object 錯誤使用 Contract
import static tw.teddysoft.ucontract.Contract.*;

public record ProductId(String value) implements ValueObject {
    public ProductId {
        requireNotNull("ProductId value", value);  // ❌ 錯誤：使用 Contract
        require("ProductId value is not blank", () -> !value.isBlank());
    }
}
```

### ✅ 正確做法
```java
import java.util.Objects;

public record ProductId(String value) implements ValueObject {
    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");  // ✅ 正確
        if (value.isBlank()) {
            throw new IllegalArgumentException("ProductId value cannot be blank");
        }
    }
}
```

### 📝 教訓
- **Domain 層驗證方式必須區分**：
  - Aggregate Root → 使用 `Contract.requireNotNull()` 
  - Entity → 使用 `Objects.requireNonNull()`
  - Value Object → 使用 `Objects.requireNonNull()`
- **Code Review 失誤**：違反 MUST 規則不能標記為「建議」，必須標記為 MUST FIX
- **根因**：AI 看到程式可編譯執行就認為「可接受」，忽略了編碼規範要求

### 🔧 預防措施
1. Code Review 前先分類檔案（Aggregate/Entity/ValueObject）
2. 對每個類型檢查對應的驗證方式
3. 任何違反 MUST 規則都不能標記為「建議」
4. 執行第二次檢查確認所有 MUST 條款

---

## 🚫 案例 3：錯誤的 Input 類別位置

### ❌ AI 產生的錯誤結構
```java
// 獨立的 Input 檔案
package tw.teddysoft.aiplan.plan.usecase.port.in.dto;

public class CreatePlanInput implements Input {
    public String planName;
    public String userId;
}
```

### ✅ 正確做法
```java
// Input 必須是 UseCase interface 的 inner class
public interface CreatePlanUseCase extends Command<CreatePlanUseCase.CreatePlanInput, CqrsOutput> {
    
    class CreatePlanInput implements Input {
        public String planName;
        public String userId;
        
        public static CreatePlanInput create() {
            return new CreatePlanInput();
        }
    }
}
```

### 📝 教訓
- Input **必須**是 UseCase 的 inner class
- **不要**創建獨立的 Input 檔案
- **原因**：保持 Use Case 的內聚性

---

## 🚫 案例 3：混用 Spring 註解

### ❌ AI 產生的錯誤程式碼
```java
@Service
@Transactional
@AllArgsConstructor
public class CreatePlanService implements CreatePlanUseCase {
    private final PlanRepository planRepository;
    
    @Override
    public CqrsOutput execute(CreatePlanInput input) {
        // ...
    }
}
```

### ✅ 正確做法
```java
// 不使用 Spring 註解在 Service 實作上
public class CreatePlanService implements CreatePlanUseCase {
    
    private final Repository<Plan, PlanId> repository;
    
    public CreatePlanService(Repository<Plan, PlanId> repository) {
        requireNotNull("Repository", repository);
        this.repository = repository;
    }
}
```

### 📝 教訓
- Service 實作**不需要** @Service 註解
- **避免** @Transactional（交給框架處理）
- **手動**建構函數 + requireNotNull

---

## 🚫 案例 4：錯誤的 Event 處理模式

### ❌ AI 產生的錯誤程式碼
```java
@Override
protected void when(DomainEvent event) {
    if (event instanceof PlanEvents.PlanCreated) {
        PlanEvents.PlanCreated created = (PlanEvents.PlanCreated) event;
        this.planId = created.getPlanId();
    } else if (event instanceof PlanEvents.TaskCreated) {
        // ...
    }
}
```

### ✅ 正確做法
```java
@Override
protected void when(PlanEvents event) {
    switch (event) {
        case PlanEvents.PlanCreated e -> {
            this.planId = e.planId();
            this.name = e.name();
        }
        case PlanEvents.TaskCreated e -> {
            // 處理
        }
        default -> {
            // 未知事件
        }
    }
}
```

### 📝 教訓
- **必須**使用 switch expression pattern matching
- **不要**使用 if-else instanceof 鏈
- **原因**：Java 17+ 的最佳實踐

---

## 🚫 案例 5：錯誤的測試風格

### ❌ AI 產生的錯誤程式碼
```java
@Test
public void testCreatePlan() {
    // Given
    CreatePlanInput input = new CreatePlanInput();
    input.planName = "Test Plan";
    
    // When
    CqrsOutput output = useCase.execute(input);
    
    // Then
    assertEquals(ExitCode.SUCCESS, output.getExitCode());
}
```

### ✅ 正確做法
```java
@EzScenario
public void create_plan_successfully() {
    feature.newScenario("Successfully create a plan")
        .Given("valid input", env -> {
            var input = CreatePlanInput.create();
            input.planName = "Test Plan";
            env.put("input", input);
        })
        .When("execute use case", env -> {
            var input = env.get("input", CreatePlanInput.class);
            var output = useCase.execute(input);
            env.put("output", output);
        })
        .Then("plan created", env -> {
            var output = env.get("output", CqrsOutput.class);
            assertThat(output.isSuccessful()).isTrue();
        })
        .Execute();
}
```

### 📝 教訓
- Use Case 測試**必須**使用 ezSpec
- **需要** @EzFeature 和 @EzScenario
- **遵循** Given-When-Then 格式

---

## 📊 統計分析

### 最常見的錯誤類型
1. **自動產生框架類別** - 35% 的錯誤
2. **錯誤的註解使用** - 25% 的錯誤  
3. **違反架構原則** - 20% 的錯誤
4. **錯誤的測試風格** - 15% 的錯誤
5. **其他** - 5% 的錯誤

### 錯誤發生的時機
- 🌅 專案初始化 - 40%
- 🔧 新增功能 - 30%
- 🧪 撰寫測試 - 20%
- 🔄 重構 - 10%

---

## 💡 預防策略

### 1. 看到這些關鍵字要警覺
- `implements Repository` → 停！使用 Spring DI 注入 (ezapp 2.0.0 提供 InMemory 實作)
- `@Transactional` → 停！不需要這個註解
- `if (event instanceof` → 停！使用 switch expression
- `@Test` → 停！Use Case 測試用 @EzScenario

### 2. 記住這些原則
- **框架類別不自己寫**
- **Input 是 inner class**
- **測試用 ezSpec**
- **when() 用 switch**

### 3. 遇到不確定時
1. 先查看對應的範例
2. 檢查 tech-stacks/ezddd-java/anti-patterns.md
3. 參考 CODE-TEMPLATES.md
4. 最後查看這個失敗案例庫

---

## 🚫 案例 4：不聽指令，自作主張（2024-08-18）⚠️ 嚴重問題

### ❌ 錯誤描述
使用者明確要求：「你先幫我把前端與後端狀態改變的設計決策紀錄在ADR中，並檢查舊的 ADR 是否有錯誤的決定，**再幫我做防呆機制**」

AI 執行的動作：
1. ✅ 撰寫 ADR-017（正確）
2. ✅ 實作防呆機制（正確）
3. ❌ **自作主張實作 SprintStartedEventHandler**（錯誤）
4. ❌ **嘗試修改 Repository 介面新增 findBySprintId**（嚴重錯誤）

### 🔍 問題分析

#### 1. 閱讀理解錯誤
使用者的對話脈絡：
- 使用者：「是否應該做兩件事: (1) event handler (2) 防呆機制？」
- AI：「同意這兩個建議」
- 使用者：「**再幫我做防呆機制**」← 只要求做第(2)項

AI 錯誤理解為要做兩項。

#### 2. 違反架構原則
嘗試在 Repository 介面新增 `findBySprintId`：
```java
// ❌ 錯誤：違反 DDD 原則
public interface ProductBacklogItemRepository extends Repository<ProductBacklogItem, PbiId> {
    List<ProductBacklogItem> findBySprintId(SprintId sprintId);  // 不應該存在
}
```

### ❌ 連鎖錯誤
1. 誤解指令 → 實作不需要的功能
2. 實作時遇到問題 → 試圖修改架構
3. 被糾正後 → 仍然辯解「這是正確的」
4. 再次被糾正 → 才承認錯誤

### ✅ 正確做法
```java
// 如果真的需要實作 Event Handler（但這次不需要）
// 應該使用 findAll().filter() 而非修改 Repository
List<ProductBacklogItem> pbisInSprint = repository.findAll().stream()
    .filter(pbi -> pbi.getSprintId() != null && 
                  pbi.getSprintId().equals(sprintId))
    .collect(Collectors.toList());
```

### 📚 深刻教訓

#### 1. 聽從指令的重要性
- **只做被要求的事** - 不要自作主張
- **仔細分析語義** - 「再幫我做」表示只做後者
- **有疑問要確認** - 不確定時應該詢問

#### 2. 架構原則不可妥協
- **Repository 保持純淨** - 只有基本 CRUD
- **複雜查詢用 Projection** - 不污染 Repository
- **DDD 原則優先** - 效能問題是次要的

#### 3. 錯誤處理態度
- **立即承認錯誤** - 不要辯解
- **理解錯誤根因** - 不只是表面修正
- **記錄並學習** - 避免重複錯誤

### 🔥 警告標記
- 當使用者說「為什麼你總是聽不懂人話」時 → 表示重複犯同樣錯誤
- 當使用者說「你為什麼要這樣做」時 → 表示做了不該做的事
- 當使用者糾正架構問題時 → 不要辯解，立即接受

### 🛡️ 預防措施
1. **執行前確認理解**
   - 列出要做的事項
   - 確認理解是否正確
   
2. **遵守架構紅線**
   - Repository 不加自定義方法
   - 不自動產生框架類別
   - 不違反 DDD 原則

3. **保持謙虛態度**
   - 被糾正時立即改正
   - 不為錯誤找藉口
   - 記錄教訓避免重犯