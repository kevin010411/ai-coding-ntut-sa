# Generation Templates 目錄

## 📋 概述

本目錄包含完整的程式碼生成模板，用於協助 AI 助手快速生成符合專案規範的完整功能模組。

## 🎯 與 examples 其他目錄的區別

- **examples/** - 展示單一模式的範例程式碼，用於學習和參考
- **templates/**（本目錄）- 提供完整的多檔案生成模板，用於快速產生整個功能模組

## 📁 模板清單

### ~~aggregate-usecase-full.md~~ (已移除)
此模板已拆分為獨立的 pattern 檔案：
- Domain 層 → `patterns/domain/aggregate.md`, `domain-event.md`, `value-object.md`
- UseCase 層 → `patterns/usecase/command.md`
- Testing → `patterns/testing/usecase-test.md`, `contract-test.md`

使用時機：請直接參考對應的 pattern 檔案

### reactor-full.md
完整的 Reactor 生成模板，包含：
- Reactor Interface
- Reactor Implementation
- Event Handler 配置
- 測試案例

使用時機：需要實作 Domain Event 的處理邏輯

### complex-aggregate-spec.md
複雜聚合根的規格定義模板，使用 YAML 格式描述：
- 實體層次結構（含繼承關係）
- 業務不變量和規則
- 領域事件定義
- 命令和業務操作
- 實體間關係

使用時機：在實作前定義複雜的聚合根結構（如包含多個子實體的情況）

### test-case-full.md
> ⚠️ **部分內容已過時**：以下項目已由 ezapp 2.0.0 框架取代，不再需要自訂：
> - ~~TestContext 單例模式~~ → 使用 `BaseUseCaseTest`
> - ~~BlockingMessageBus 設置~~ → 使用 `SharedInfrastructureConfig` 提供的 `InMemoryMessageBroker`
> - ~~GenericInMemoryRepository 配置~~ → 使用框架內建的 `InMemoryOrmDb` + `InMemoryOrmClient`
>
> 請改用 `base-test-classes.md` 和 `aggregate-config-template.md` 的現行模板。

仍然有效的內容：
- Domain Event 捕獲機制
- ezSpec BDD 測試結構

使用時機：需要為 Use Case 生成完整的測試類別（建議搭配 `base-test-classes.md` 使用）

### local-utils.md
專案必須生成的共用類別模板，包含：
- DateProvider - 時間控制工具類別
- 正確的 ezapp-starter import 路徑說明
- ⚠️ `GenericInMemoryRepository` 已由 ezapp 2.0.0 框架提供，不再需要自訂

使用時機：新專案初始化時必須生成的共用元件

### aggregate-config-template.md ⭐ NEW
Aggregate-Specific Configuration 生成模板，支援平行執行：
- `[Aggregate]InMemoryRepositoryConfig.java` - InMemory Repository 配置
- `[Aggregate]OutboxRepositoryConfig.java` - Outbox Repository 配置
- `[Aggregate]UseCaseConfig.java` - Use Case 配置
- `[Aggregate]OrmClient.java` - JPA ORM Client

使用時機：創建新 Aggregate 時，需要產生獨立的 Config 類別以支援 code executor 平行執行

相關文件：
- `aggregate-config-template.md` - Aggregate-Specific Config 完整模板

## 💡 使用指引

### 1. 選擇合適的模板
根據需求選擇對應的生成模板：
- 定義複雜業務結構 → `complex-aggregate-spec.md`（設計階段）
- 創建新聚合根 → `aggregate-usecase-full.md`（實作階段）
- 創建事件處理器 → `reactor-full.md`（實作階段）

### 2. 替換佔位符
模板中的佔位符說明：
- `[Aggregate]` - 大寫開頭的聚合根名稱（如 Plan, Task）
- `[aggregate]` - 小寫的聚合根名稱（如 plan, task）
- `[AGGREGATE]` - 全大寫的聚合根名稱（如 PLAN, TASK）

### 3. 生成檔案
根據模板生成所有必要的檔案，確保：
- 檔案路徑正確
- Package 名稱一致
- Import 語句完整

### 4. 驗證生成結果
- 編譯通過
- 測試案例通過
- 符合專案規範

## 📝 注意事項

1. **完整性**：這些模板生成的是完整功能模組，包含多個相關檔案
2. **一致性**：確保所有生成的檔案之間的命名和引用保持一致
3. **客製化**：根據實際需求調整模板內容，不要盲目套用
4. **測試優先**：生成程式碼後立即撰寫並執行測試

## 📌 SSOA (Single Source of Authority) 原則

模板中嵌入的 pattern 和規則都有明確的權威來源（authority），以 `@authority` 標記追蹤。

### @authority 標記格式

```markdown
<!-- @authority: topic_id | source: authority_file#section -->
```

### 維護規則

1. **修改 pattern 前**：先查 `AUTHORITY-REGISTRY.yaml` 找到 authority 檔案
2. **只修改 authority 檔案**：然後同步所有 consumers（含 templates）
3. **新增概念時**：先在 registry 註冊 topic，再寫入 authority
4. **修改 template 後**：執行 `scripts/check-pattern-consistency.sh` 驗證一致性

### 驗證

```bash
# 驗證所有 template 與 authority 的一致性
./scripts/check-pattern-consistency.sh
```

詳見：`references/AUTHORITY-REGISTRY.yaml`

## 🔗 相關資源

- [Domain 層 Patterns](../patterns/domain/)
- [UseCase 層 Patterns](../patterns/usecase/)
- [Testing Patterns](../patterns/testing/)
- [共用規則](../rules/)