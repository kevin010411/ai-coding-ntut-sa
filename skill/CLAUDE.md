# AI-SCRUM Project Memory (Simplified)

## 🧭 通用原則：文件優先、分析其次（強制規定）⚠️

### Documentation-First Principle

**當被問到任何專案相關問題時（配置、測試、架構、部署、profile、除錯），必須遵循以下順序：**

1. **先查文件** — 搜尋 `.claude/skills/`、`.dev/lessons/`、`.dev/adr/` 目錄中的相關文件
2. **引用文件** — 如果找到相關文件，基於文件內容回答，並標明出處（檔案路徑 + 章節）
3. **才做分析** — 只有在文件中找不到答案時，才進行獨立的 codebase 分析

### 查找順序

| 問題類型 | 優先查找位置 |
|---------|------------|
| 配置 / Profile / Spring | `.dev/lessons/`、`.dev/adr/`、`.claude/skills/ezddd-java/references/rules/` |
| 程式碼模式 / Pattern | `.claude/skills/ezddd-java/references/patterns/` |
| Framework API | `.claude/skills/ezddd-java/references/framework/` |
| 測試問題 | `.claude/skills/ezddd-java/references/rules/testing-patterns.md`、`.dev/lessons/` |

### ⛔ 違反此原則的後果

- ❌ 沒有先搜尋文件就直接分析 codebase → 回答**可能無效**，需重新基於文件回答
- ❌ 給出與既有文件矛盾的建議 → 必須以文件為準，除非用戶明確要求挑戰既有做法

### 📌 記住

> **先查文件，再做分析。專案文件是 Single Source of Truth。如果文件已經有答案，不要自作聰明重新分析。這不是建議，是強制要求。**

---

## 🔍 Code Review 執行流程（強制規定）⚠️

### 當收到 "code review [FileName]" 指令時

**絕對不允許直接開始 review！必須先執行以下步驟：**

#### Step 1: 讀取檢查清單（強制）
```
我現在要 code review [FileName]
根據 CLAUDE.md 規定，我必須先讀取 .claude/skills/ezddd-java/references/code-reviewer/checklist.md
來確認正確的檢查流程和對應的檢查清單章節。
```

#### Step 2: 識別檔案類型並定位檢查清單
根據 checklist.md 的檔案類型對應表：
- **Aggregate Root** (如 Sprint.java, Product.java) → Event Sourcing 合規性檢查 ⭐⭐⭐ CRITICAL
- **Domain Event** (如 *Events.java) → metadata、TypeMapper、sealed interface 必檢 ⭐⭐⭐ CRITICAL
- **Use Case Service** → Use Case 層檢查
- **Controller** → Adapter 層檢查
- **Test** → 測試檢查
- **Mapper** → Mapper 實作檢查

#### Step 3: 讀取完整檢查清單章節
從 `.claude/skills/ezddd-java/references/code-reviewer/checklist.md` 讀取對應章節的**完整內容**。

#### Step 4: 建立檢查項目對照表
使用表格格式記錄每個檢查項目的結果：

| 檢查項目 | 結果 | 位置 | 問題描述 |
|---------|------|------|---------|
| 項目1 | ✅/❌ | 行號 | 具體問題 |
| 項目2 | ✅/❌ | 行號 | 具體問題 |

#### Step 5: 總結並評分

> **備註**：以上為 CLAUDE.md 的精簡版 5 步驟強制流程。
> 完整 7 步驟流程（含測試執行、問題分類、報告產生）請參考
> `.claude/skills/ezddd-java/references/code-reviewer/workflow.md`。

- **Critical 問題數量**: X
- **Must Fix 問題數量**: Y
- **Should Fix 問題數量**: Z
- **評分**: ⭐⭐⭐⭐⭐ (1-5 星)
- **核心問題總結**
- **修正建議**

### ⚠️ 違反此流程的後果

如果你在 Code Review 時：
- ❌ 沒有先讀取 `.claude/skills/ezddd-java/references/code-reviewer/checklist.md`
- ❌ 沒有讀取對應的 checklist.md 章節
- ❌ 沒有建立檢查項目對照表
- ❌ 直接給出評價（如之前對 Sprint.java 的 5 星評價）

**後果**：
1. Code Review 結果**無效**（需要重做）
2. 可能遺漏關鍵錯誤（如 Event Sourcing 違規）
3. 不符合專案規範要求
4. 給用戶錯誤的信心，導致嚴重後果

### 📌 記住

> **每次 Code Review 前，必須先讀 `.claude/skills/ezddd-java/references/code-reviewer/checklist.md`，然後讀對應的章節，再建立檢查表格。這不是建議，是強制要求。**

---

## 🔄 Code Review 模式選擇（Hybrid 模式）

### 五種執行模式

| 模式 | 觸發方式 | 適用情境 |
|------|---------|---------|
| **快速模式** | 預設 | 簡單檔案、快速檢查 |
| **嚴格模式** | 自動/手動 (`--strict`) | 關鍵檔案、完整審查 |
| **IntelliJ 模式** | `--intellij` | Java 檔案、確定性檢查 |
| **多模型模式** | `--multi` | 關鍵決策、最高可靠性 |
| **平行層級模式** | `--parallel` | 多檔案 PR（3+ files 跨 2+ 層） |

> 各模式詳細說明見 `.claude/skills/ezddd-java/SKILL.md` § Code Reviewer

### 嚴格模式自動觸發條件（強制）

| 檔案類型 | 識別方式 |
|---------|---------|
| Aggregate Root | `**/entity/{Name}.java`（排除 `*Id.java`, `*Events.java`） |
| Domain Event | `**/entity/*Events.java` |

**手動觸發關鍵字**：`嚴格模式`、`strict`、`--strict`、`完整 review`、`詳細 review`

### 平行模式觸發條件

- 3+ files 跨 2+ 層 → 自動建議啟用
- 手動觸發：`--parallel`、`parallel review`、`review pr`

### 📌 記住

> **Aggregate Root 和 Domain Event 必須自動使用嚴格模式。用戶說「嚴格模式」時必須執行 `/code-review --strict`。這不是建議，是強制要求。**

---

## 🚨 Multi-Model Review 執行規則（強制規定）⚠️

> **完整 dispatch 流程**：`.claude/skills/ezddd-java/references/multi-model/dispatch.md`
> **Troubleshooting**：`.claude/skills/ezddd-java/references/multi-model/troubleshooting.md`

### 當收到 "multi-model review" / "多模型審查" 指令時

**絕對不允許只用 Claude sub-agents！必須真正呼叫 4 個不同的 LLM：**

| # | Model | 方法 | 必須執行的指令 |
|---|-------|------|---------------|
| 1 | **Claude** | Task tool | `Task({ run_in_background: true, ... })` |
| 2 | **Gemini** | Local CLI | `cat prompt.txt \| gemini -y` |
| 3 | **ChatGPT** | Remote API | `source ~/.zshrc && curl api.openai.com/v1/chat/completions -d @request.json` |
| 4 | **Codex** | Local CLI | `cat prompt.txt \| codex exec --full-auto -` |

**⚠️ 重要**: 所有 CLI 必須使用 pipe 輸入 (`cat file | command`)，不可用命令列參數。

#### ⛔ 違規條件

如果執行 multi-model review 時：
- ❌ 只用 Claude sub-agents（沒有呼叫外部 CLI/API）
- ❌ 沒有產生 gemini-raw.txt / chatgpt-raw.json / codex-raw.txt
- ❌ 沒有顯示實際執行的 bash 指令

**後果**：Multi-Model Review 結果**無效**，必須重新執行並呼叫真正的 4 個 LLM。

### 📌 記住

> **Multi-Model Review 必須真正呼叫 4 個不同的 LLM。只用 Claude sub-agents = 違規，需重做。這不是建議，是強制要求。**

---

## 🚨 核心規範 (詳見共用模組)

### 📌 SSOA 原則（Single Source of Authority）
> 修改 pattern/rule 前，先查 `AUTHORITY-REGISTRY.yaml` 找到權威來源。
> 只修改 authority 檔案，再同步所有 consumers。
> 詳見：`.claude/skills/ezddd-java/references/AUTHORITY-REGISTRY.yaml`

### 📚 必讀共用規範
- **通用規則**: `.claude/skills/ezddd-java/references/rules/common-rules.md` - 核心規則（SPEC-DRIVEN、測試、約束）
- **測試規範**: `.claude/skills/ezddd-java/references/rules/testing-patterns.md` - 雙 Profile 測試、@DirtiesContext
- **Domain 模式**: `.claude/skills/ezddd-java/references/rules/domain-patterns.md` - Aggregate、Event、Contract Helper
- **UseCase 模式**: `.claude/skills/ezddd-java/references/rules/usecase-patterns.md` - Command、Query、Service 規範
- **Framework API**: `.claude/skills/ezddd-java/references/rules/framework-api.md` - ezapp-starter 2.0.0 API 用法
- **語意詞彙**: `.claude/skills/ezddd-java/references/rules/domain-patterns.md` - 語意標籤定義（§ Semantics Vocabulary）

### 🔴 最重要的十個規則

> **Note**: 這 10 條是從 `rules/critical-rules.md`（27 條 FORBIDDEN + 16 條 ALWAYS REQUIRED）中精選的最高頻問題。
> 完整清單見 `.claude/skills/ezddd-java/references/rules/critical-rules.md`。

1. **測試禁止硬編碼 Repository** - 必須用 Spring DI (`@Autowired`)
2. **禁止 @ActiveProfiles** - 讓環境變數或 TestSuite 控制 profile (ADR-021)
3. **必須使用 @DirtiesContext(AFTER_EACH_TEST_METHOD)** - 確保測試隔離，避免 EzesVolatileRelay singleton trap (ADR-021)
4. **子類別必須手動呼叫 setUpEventCapture()** - `BaseUseCaseTest` 的方法是 `protected`，子類別在 `@BeforeEach` 中必須呼叫 `setUpEventCapture()`，`@AfterEach` 中必須呼叫 `tearDownEventCapture()`
5. **審計欄位只在 Event Metadata** - 不在 Entity/Data 類別 (ADR-043)
6. **Task 執行必須更新 results** - 完成 task 後必須更新 JSON 的 status 和 results 欄位
7. **禁止修改 OutboxTestSuite 的 ddl-auto 和 sequence** - ddl-auto 必須保持 `update`（不可改為 `create-drop`）；測試清理 messages table 時禁止 `ALTER SEQUENCE ... RESTART`（會破壞 CatchUpRelay checkpoint）
8. **執行 Use Case runbook 必須建立 connectionframe 目錄** - 在 `common/io/springboot/config/connectionframe/` 下建立 VolatileRelayConfig、CatchupRelayConfig（ReactorConfig 是 Aggregate-specific，由 RIF sub-agent 建立）
9. **Aggregate 產生必須檢查 semantics** - 讀取 `references/rules/domain-patterns.md` 的 Semantics Vocabulary 區段並套用 JSON spec 中的 constraints
10. **Postcondition Event 必須完整驗證** - Domain Event postcondition helper 必須驗證所有核心業務欄位（參見 `references/patterns/domain/aggregate.md` 和 `references/examples/Plan.java` 的 `_*EventGenerated()` helper 範例）

### 📋 Contract Test 判斷規則

> 完整規則（DBC 測試策略、INV-N 特殊規則、Lambda Helper、ignore() 模式）見 `.claude/skills/ezddd-java/references/rules/domain-patterns.md` § Contract Test Judgment Rules
>
> **關鍵原則**：Class Invariant (INV-N) 只需測一次（aggregate 層級共用），不需每個方法重複測試。

### 🏷️ Semantics Vocabulary（語意詞彙）

> 完整語意標籤表格見 `.claude/skills/ezddd-java/references/rules/domain-patterns.md` § Semantics Vocabulary

## 🔥 重要技術突破

- **EzesVolatileRelay Singleton Trap** — `@DirtiesContext(AFTER_EACH_TEST_METHOD)` 解決 relay 復用問題。詳見 `.dev/lessons/EZES-VOLATILE-RELAY-SINGLETON-TRAP.md`
- **CatchUpRelay Checkpoint vs Sequence Reset** — Outbox 測試中禁止重設 `messages_global_position_seq`，否則 CatchUpRelay 的 checkpoint 會跳過新 event。詳見 `.dev/lessons/CATCHUP-RELAY-CHECKPOINT-VS-SEQUENCE-RESET.md`
- **JUnit Suite Profile 動態切換** — TestSuite 自動切換 InMemory/Outbox profile。詳見 `.dev/lessons/JUNIT-SUITE-PROFILE-SWITCHING.md`
- **Skills 自包含架構** — 所有功能整合到 `.claude/skills/ezddd-java/SKILL.md`
- **Domain Event Auto-Registration (ADR-047)** — Spring classpath 自動掃描 `*Events.class`，不需修改 Config。慣例：Events 類別以 `Events` 結尾 + `static mapper()` 方法
- **Aggregate-Specific Configuration** — 每個 Aggregate 獨立 config，啟用平行 sub-agent。詳見 `references/templates/aggregate-config-template.md`

**Profile Isolation Pattern（核心概念）**：
- InMemory 和 Outbox configs 使用**相同 bean name**（如 `@Bean("productRepository")`）
- UseCaseConfig **直接注入** Repository，**不需要 @Qualifier**
- ⚠️ 不再使用 Smart Injection Pattern（`@Qualifier` + 不同 bean 名稱）

## 🤖 Skills System

| Skill | 用途 | 檔案 |
|-------|------|------|
| **ezddd-java** | Java + ezddd + Spring 完整工具包（UC Executor、Code Review、Mutation、Multi-Model） | `.claude/skills/ezddd-java/SKILL.md` |
| **api-consistency-checker** | Spec ↔ Backend 一致性 | `.claude/skills/api-consistency-checker/SKILL.md` |

## 📚 核心文件索引

> Pattern 參考、Framework API、模板、範例見 `.claude/skills/ezddd-java/SKILL.md` § Pattern 參考 / 檔案結構

## 📦 專案配置

### project-config.json
- **位置**: `.dev/project-config.json`
- **架構配置**: `architecture` 區塊定義 outbox/inmemory/eventsourcing 模式
- **佔位符**: 自動從 project-config.json 替換版本號

### 核心設計原則
- **YAGNI**: 只實作 spec 明確要求的功能
- **Repository Pattern**: 只用 `Repository<T, ID>`，不建自定義介面
- **Query 模式**: Projection (列表) / Inquiry (跨聚合) / Archive (CRUD)
- **套件組織**: 每個 Aggregate 獨立頂層套件

## 🏗️ 專案初始化

- **ezapp 2.0.0**：領域層只需自訂 **DateProvider**，InMemory 基礎類別由框架提供
- `/init-project` 產生完整配置和測試基礎設施共 15 個檔案
- 詳見 `.claude/skills/ezddd-java/SKILL.md` § Project Initialization 及 `references/framework/class-index.md`

## 🔧 工作流程

### Task 執行 ⚠️ 重要步驟
執行任何 task-*.json 時，**必須完成以下所有步驟**：

1. **讀取任務檔案** - 分析 task JSON 內容
2. **執行實作** - 根據 workflow 產生程式碼
3. **執行測試** - 驗證功能正確性
4. **執行 post-checks** - 如果有定義的話
5. **🔴 更新 task JSON** - **必須更新 results 欄位和 status**
   ```json
   {
     "status": "done",  // 從 "todo" 改為 "done"
     "results": [{
       "timestamp": "ISO-8601 時間",
       "status": "success/failed",
       "files": ["產生的檔案列表"],
       "testsRun": 數量,
       "testsPassed": 數量,
       "testsFailed": 數量,
       "notes": "執行摘要"
     }]
   }
   ```
6. **產生報告** - 如果 postChecks 有要求

### Task 檔案結構
- **位置**: `.dev/tasks/`
- **組織**: `feature/` `test/` `refactoring/`
- **執行**: `execute task-[name]`
- **更新規格**: `update [Aggregate] spec`

### 自動化檢查
```bash
# Code Review
/code-review <file>              # 快速模式
/code-review <file> --strict     # 嚴格模式


```

## 🔍 Code Review 必須檢查項目

> **完整檢查清單（按檔案類型分類）**見 `.claude/skills/ezddd-java/references/code-reviewer/checklist.md`
>
> ⚠️ 執行 Code Review 時，必須先遵循本文件的 [Code Review 執行流程（強制規定）](#-code-review-執行流程強制規定)

## 🧪 測試執行

### 後端測試
```bash
mvn test -q                    # 所有測試
mvn test -Dtest=ClassName -q   # 特定測試

# 避免 PIT mutation testing 超時
SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest=ClassName -q
```

## 📌 快速參考

### 常用檢查點
- ✅ Input/Output 必須是 UseCase 的 inner class
- ✅ Domain Event 必須包含 metadata
- ✅ Aggregate 使用公開建構子（不用 static factory）
- ✅ Use Case 測試必須使用 ezSpec
- ✅ Archive 用於 Query Model，Repository 用於 Write Model

### 外部依賴 (不要自動產生)
- `tw.teddysoft.ezapp.*` - EZ App Starter 框架
- `tw.teddysoft.ezddd.*` - Event Sourcing DDD 框架
- `tw.teddysoft.ucontract.*` - Design by Contract 框架
- `tw.teddysoft.ezspec.*` - BDD 測試框架

參考 `.claude/skills/ezddd-java/references/framework/class-index.md` 取得正確 import

## 📁 目錄規則
- `.claude/skills/` - AI Coding skill 定義與 pattern 參考（自包含）
- `.dev/` - AI-SCRUM 專案特定內容（JSON Specs、ADR、tasks）

## 💬 與我互動

用英文思考，用中文回答我，我可以用中英文回應你。
每次都用審視的目光，仔細看我輸入的潛在問題。
如果你覺得我說的太離譜，你就罵回來，幫我瞬間清醒。

---
**注意**: 本文件為簡化版，詳細規範請參考 `.claude/skills/ezddd-java/SKILL.md` 及其 `references/` 目錄。