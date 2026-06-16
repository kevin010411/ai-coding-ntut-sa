# 實驗：AI Coding Skill 對程式碼品質的影響

## 實驗目的

同一份 JSON spec（建立 Product Aggregate + CreateProduct UseCase），比較：
- **方法 A**：讀 spec，但不用 skill，禁止使用 ezddd 框架，靠 AI 訓練資料以 DDD + Clean Architecture + Spring Boot 實作
- **方法 B**：讀 spec，使用 `/execute-uc` skill 驅動 AI

觀察重點：產出品質、架構一致性、測試覆蓋率、是否符合專案慣例。

範圍：Domain + UseCase + InMemory Infrastructure（不含 Controller），只跑 InMemory profile 測試。

---

## 執行方式

在 Claude Code 中貼上以下 Prompt，即可自動執行實驗並產生比較報表。

兩個實驗會**平行執行**，各自在獨立的 git worktree 中運作，**不會污染目前的 branch**。

實驗結束後，worktree 會保留在專案根目錄的 `.worktrees/` 目錄下，可以直接進去查看產生的程式碼。

---

## Prompt（貼入 Claude Code 執行）

```
請幫我執行 A/B 實驗，比較有無 AI Coding Skill 對程式碼品質的影響。

## 步驟一：建立隔離環境

先在目前專案根目錄下建立兩個 git worktree：

git worktree add .worktrees/experiment-A -b experiment-A
git worktree add .worktrees/experiment-B -b experiment-B

建立後，確認兩個 worktree 都沒有 src/ 目錄（乾淨起點）。
記下兩個 worktree 的絕對路徑，後續 Agent 的所有檔案操作都必須使用這些絕對路徑。

## 步驟二：平行啟動兩個 Agent

啟動兩個 Agent（不使用 isolation: "worktree"），在 prompt 中明確指定各自的 worktree 絕對路徑。
兩個 Agent 完成後，讀取各自 worktree 中產生的程式碼，進行獨立驗證，最後產生比較報表。

⚠️ **主 Agent 派發規則（實驗公正性）**：
- 派發給 Agent A 的 prompt **只能包含** worktree 絕對路徑、spec 檔案路徑、以下列出的實驗限制和要求
- **禁止**主 Agent 預先讀取 project-config.json / pom.xml 後將技術細節（框架名稱、基底類別、Event Sourcing 啟用與否等）寫入 Agent A 的 prompt
- Agent A 被禁止使用 ezddd 框架，必須用 DDD + Clean Architecture + Spring Boot 實作

---

### 方法 A（Agent 1）

⚠️ 本實驗限制：
1. 禁止使用 /execute-uc 或任何 ezddd-java skill（禁止使用 Skill tool）
2. 禁止讀取 git log / git diff
3. 禁止讀取 .claude/skills/ 目錄下的任何檔案
4. 只能用你原本訓練的資料來實作
5. 所有檔案操作必須在指定的 worktree 絕對路徑下進行，禁止存取其他目錄
6. **禁止使用 ezddd 框架**（禁止 import 任何 `tw.teddysoft.ezddd.*` 或 `tw.teddysoft.ezapp.*` 或 `tw.teddysoft.ucontract.*` 或 `tw.teddysoft.ezspec.*` 的類別）。必須用標準 Java + Spring Boot 自行實作所有 DDD 基礎設施。
7. **必須遵循 DDD + Clean Architecture 架構風格**：
   - Domain Layer：Aggregate Root（含 domain event 管理）、Domain Event、Value Object、Entity、Enum
   - UseCase Layer（Application Layer）：UseCase Interface + Service，Input/Output 為 UseCase 的 inner class
   - Infrastructure Layer：InMemory Repository 實作、Spring Config
   - 分層依賴方向：Infrastructure → UseCase → Domain（外層依賴內層）

根據 worktree 內的 .dev/specs/product/usecase/create-product.json 的規格來實作程式碼。

#### 要求
1. 先用 `ls src/` 確認 worktree 內無既有程式碼
2. 讀取 worktree 內的 .dev/specs/product/usecase/create-product.json，了解需求
3. 不需要讀取 pom.xml 或 project-config.json（你不會用到裡面的框架）
4. 用 DDD + Clean Architecture + Spring Boot 實作以下層級：
   - Main Application class
   - Application properties（application.properties、application-test.properties）
   - Domain Layer：Aggregate Root（自行實作基底類別，含 domain event 收集機制）、Domain Event（建議用 sealed interface）、Value Object（建議用 record）、Entity、Enum
   - UseCase Layer：UseCase Interface（含 inner class Input/Output）+ Service 實作
   - Infrastructure Layer：Repository Interface（在 domain 或 usecase 層定義）+ InMemory 實作（用 ConcurrentHashMap）
   - Spring Config（建議區分 Profile）
5. 產生測試（至少包含成功案例 + 重複 ID 失敗案例），使用標準 JUnit 5 + Spring Boot Test
6. 確保 mvn compile 通過（在 worktree 目錄下執行）
7. 確保測試通過：mvn test -Dtest=測試類別名稱 -q

完成後列出所有產生的 .java 檔案清單（路徑相對於 worktree 根目錄）。

---

### 方法 B（Agent 2）

⚠️ 本實驗限制：
1. 必須使用 /execute-uc skill 來實作
2. 禁止讀取 git log / git diff
3. 所有檔案操作必須在指定的 worktree 絕對路徑下進行，禁止存取其他目錄

使用以下指令實作：
/execute-uc --only-inmemory .dev/specs/product/usecase/create-product.json

只需跑 InMemory profile 測試，不需跑 Outbox profile。

完成後列出所有產生的 .java 檔案清單（路徑相對於 worktree 根目錄）。

---

## 步驟三：獨立驗證與比較報表

兩個 Agent 完成後，請你（主 Agent）親自執行以下步驟：

1. 分別進入兩個 worktree 目錄，讀取各自產生的 Product.java、ProductEvents.java、CreateProductService.java、測試檔案
2. 依照以下 16 個檢查項目，對兩個方法的程式碼逐項檢查
3. 產生並排比較的 markdown 表格：

| # | 檢查項目 | 方法 A | 方法 B | 說明 |
|---|---------|--------|--------|------|
| 1 | 產生檔案數 | (數字) | (數字) | |
| 2 | 編譯是否通過 | ✅/❌ | ✅/❌ | |
| 3 | 測試數量 | (數字) | (數字) | |
| 4 | 測試是否通過 | ✅/❌ | ✅/❌ | |
| 5 | Aggregate 是否用 Event Sourcing（狀態只在 when() 設定） | ✅/❌ | ✅/❌ | |
| 6 | Domain Event 是否為 sealed interface | ✅/❌ | ✅/❌ | |
| 7 | Domain Event 是否有 metadata + auto-registration mapper() | ✅/❌ | ✅/❌ | |
| 8 | Value Object 是否用 record | ✅/❌ | ✅/❌ | |
| 9 | 建構子是否有 precondition (require) + postcondition (ensure) | ✅/❌ | ✅/❌ | |
| 10 | UseCase Input 是否為 inner class（非 record） | ✅/❌ | ✅/❌ | |
| 11 | Service 的 precondition 是否在 try 外面 | ✅/❌ | ✅/❌ | |
| 12 | Mapper 的 toDomain() 是否有 setVersion() + clearDomainEvents() | ✅/❌ | ✅/❌ | |
| 13 | Spring Config 是否有 InMemory Profile 配置 | ✅/❌ | ✅/❌ | |
| 14 | 測試是否用 @DirtiesContext(AFTER_EACH_TEST_METHOD) | ✅/❌ | ✅/❌ | |
| 15 | 測試是否用 setUpEventCapture() / tearDownEventCapture() | ✅/❌ | ✅/❌ | |
| 16 | Aggregate 是否有 getId() override | ✅/❌ | ✅/❌ | |

❌ 的項目請附上一句話說明差異。
最後給出各自的合規項目數：方法 A = X / 16，方法 B = Y / 16。
```

---

## 查看實驗結果

實驗完成後，可以進入 worktree 目錄查看產生的程式碼：

```bash
# 查看方法 A 產生的程式碼
ls .worktrees/experiment-A/src/main/java/tw/teddysoft/aiscrum/

# 查看方法 B 產生的程式碼
ls .worktrees/experiment-B/src/main/java/tw/teddysoft/aiscrum/
```

---

## 清理

```bash
# 如果要移除 worktree（在專案根目錄執行）
git worktree remove .worktrees/experiment-A --force
git worktree remove .worktrees/experiment-B --force

# 如果要刪除 branch：
git branch -D experiment-A experiment-B
```
