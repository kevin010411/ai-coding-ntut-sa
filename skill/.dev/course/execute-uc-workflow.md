> 教我 execute-uc 的工作流程


`★ Insight ─────────────────────────────────────`
UC Executor 的設計體現了 **Spec-Driven Development** 的核心思想：JSON spec 是 Single Source of Truth，程式碼是 spec 的衍生物。這跟傳統「先寫 code 再補文件」的流程完全相反。兩個 Quality Gate 的設計也很精妙——Gate 1 確保功能正確性（雙 profile 測試），Gate 2.5 確保程式碼結構合規（deterministic pattern matching）。
`─────────────────────────────────────────────────`

## Execute-UC 工作流程教學

`/execute-uc` 是從 **JSON UseCase 規格書** 自動產生 DDD 程式碼的完整流水線，共 7 個 Phase、2 道 Quality Gate。

---

### 整體流程圖

```
JSON Spec (.dev/specs/{aggregate}/usecase/*.json)
    │
    ▼
Phase 0: 準備 ─── 驗基礎設施 → 讀 spec → 偵測類型 → 驗必填欄位
    │
    ▼
Phase 1: 學習 ─── 載入 critical-rules.md + json-to-pattern-mapping.md
    │
    ▼
Phase 2: 產碼 ─── 根據 spec type 走不同路徑（COMMAND / QUERY / REACTOR）
    │
    ▼
Phase 3: 編譯 ─── mvn compile -q（失敗就修到過）
    │
    ▼
Phase 4: 測試 ─── ⛔ Gate 1: Dual-Profile Test（InMemory + Outbox 都要過）
    │
    ▼
Phase 5: 審查 ─── ⛔ Gate 2.5: Deterministic Review（55 條 regex 規則，0 CRITICAL）
    │
    ▼
Phase 6: 合規 ─── 驗 testScenarios 覆蓋率
    │
    ▼
Phase 7: 報告 ─── 完成報告（產生檔案列表 + Gate 結果）
```

---

### Phase 0: 準備

做四件事：

1. **驗基礎設施** — `DomainEventMapperConfig`、`DateProvider` 等是否存在，缺了就自動觸發 `/init-project`
2. **讀 JSON Spec** — 從 `.dev/specs/` 讀取規格書
3. **偵測 Spec 類型**：

| 判斷條件 | 類型 |
|---------|------|
| 有 `useCase` + `domainEvent` | **COMMAND**（狀態變更） |
| 有 `query` + `projections` | **QUERY**（查詢） |
| 有 `reactor` + `events` | **REACTOR**（事件反應器） |

4. **驗必填欄位** — 缺欄位直接 ⛔ STOP，不會硬猜

---

### Phase 1: 學習（JIT Pattern Loading）

這步非常關鍵——**LLM 在產碼前必須先讀規則**：

- `critical-rules.md`：27 條 FORBIDDEN + 16 條 REQUIRED（品質底線）
- `json-to-pattern-mapping.md`：JSON 欄位 → pattern 檔案的對照表

`★ Insight ─────────────────────────────────────`
這是一個 **Just-In-Time Learning** 的設計。LLM 不是靠「記憶」寫 code，而是每次都重新讀規則。這解決了 LLM「幻覺」問題——即使模型換了版本，只要規則文件正確，產出就是正確的。
`─────────────────────────────────────────────────`

---

### Phase 2: 產碼（三條路徑）

#### COMMAND 路徑（最常見）

```
Step 4.1  → Aggregate + Events（sealed interface、apply()、when()）
Step 4.1.5→ Contract Tests（如果 spec 有 pre/postconditions）
Step 4.2  → UseCase Interface + Service（Input 用 class 不用 record！）
Step 4.3  → UseCase Test（ezSpec、@DirtiesContext、setUpEventCapture）
Step 4.4  → Infrastructure（Data、Mapper、OrmClient、InMemory/Outbox Config）
Step 4.5  → Controller（如果有 --controller flag）
Step 4.6  → Controller Test（MockMvc + REST Assured）
```

#### QUERY 路徑

```
Step 4.1 → Projection（介面 + InMemory/Outbox 實作）
Step 4.2 → Query UseCase + Service
Step 4.3 → Mapper（放 usecase.port 套件）
Step 4.4 → Test
```

#### REACTOR 路徑

```
Step 4.1 → Reactor Interface + Service
Step 4.2 → Inquiry（如果有跨 Aggregate 查詢）
Step 4.3 → Test
```

---

### Phase 3-4: 編譯 + ⛔ Gate 1（Dual-Profile Test）

```bash
# 編譯
mvn compile -q

# Gate 1: 兩個 profile 都要跑
SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest={TestClass} -q
SPRING_PROFILES_ACTIVE=test-outbox   mvn test -Dtest={TestClass} -q
```

**失敗就修 → 重跑 → 直到兩個 profile 都綠燈。**

---

### Phase 5: ⛔ Gate 2.5（Deterministic Review）

```bash
bash .claude/skills/ezddd-java/scripts/validate-generated-code.sh --aggregate {name}
```

就是你剛才問的那 55 條 regex 規則。**0 CRITICAL 才能過關。**

---

### Phase 6-7: 合規驗證 + 報告

- 每個 `testScenarios[]` 都有對應的測試方法
- 輸出完成報告，含產生的檔案列表和兩道 Gate 結果

---

### 使用方式

```bash
# 基本用法：從 spec 產生 domain + usecase + infra + test
/execute-uc .dev/specs/product/usecase/create-product.json

# 含 Controller 層
/execute-uc --controller .dev/specs/product/usecase/create-product.json

# 只驗證 spec 格式，不產碼
/execute-uc --dry-run .dev/specs/sprint/usecase/start-sprint.json
```

---

### 四個 ⛔ Blocking 條件

| 條件 | Phase | 後果 |
|------|-------|------|
| JSON 缺必填欄位 | 0 | 直接停止 |
| 編譯失敗修不好 | 3 | 卡住 |
| Dual-Profile 測試失敗 | 4 | 修到過 |
| Gate 2.5 有 CRITICAL | 5 | 修到過 |

簡單說：**Spec 進去，通過兩道 Gate 的 DDD 程式碼出來。** 你想針對哪個 Phase 深入了解嗎？
