# ADR-050: 棄用通用 Code Generation Prompt

## 狀態
已採納 (Accepted)

## 背景
專案早期使用 `code-generation-prompt.md` 作為通用的程式碼生成 prompt。隨著專案演化，我們根據 ADR-009 的決定，開發了多個專門化的 sub-agent prompts（command、query、aggregate、reactor、controller 等）。

現在需要決定是否保留這個通用的 prompt。

## 決策
**棄用並移除 `code-generation-prompt.md`**，完全使用專門化的 sub-agent prompts。

## 理由

### 1. 功能完全重複
所有領域都已有專門化 sub-agents：
- Domain 層：`aggregate-sub-agent-prompt.md`
- Command：`command-sub-agent-prompt.md`
- Query：`query-sub-agent-prompt.md`
- Controller：`controller-*-prompt.md` 系列
- Reactor：`reactor-sub-agent-prompt.md`
- Infrastructure：`outbox-sub-agent-prompt.md`

### 2. 技術債務
通用 prompt 缺乏：
- 架構感知能力（不讀 `project-config.json`）
- 精細的框架 API 規則
- 專門化的模板和範例

### 3. 違反設計原則
- 違反單一職責原則
- 與 ADR-009（Command/Query 分離）的演化方向衝突
- 增加認知負擔（不知道該用哪個 prompt）

### 4. 維護成本
- 需要同步更新多個 prompts
- 容易造成不一致
- 增加錯誤風險

## 遷移計畫

### 保留內容遷移
1. **佔位符處理規則** → `.ai/VERSION-PLACEHOLDER-GUIDE.md`
2. **Service 實作範例** → `.ai/tech-stacks/java-ezddd-spring/CODE-TEMPLATES.md`
3. **常見錯誤清單** → `.ai/tech-stacks/java-ezddd-spring/FAILURE-CASES.md`

### 檔案更新
需要更新引用 `code-generation-prompt.md` 的檔案：
- `.ai/workflows/feature-implementation.md`
- `.ai/scripts/check-coding-standards.sh`
- 各個 task 檔案中的引用

## 影響

### 正面影響
- 簡化 prompt 選擇決策
- 提高程式碼生成品質
- 降低維護成本
- 強化約束空間設計理念

### 負面影響
- 無（所有功能都已被專門化 sub-agents 涵蓋）

## 替代方案

### 方案 1：保留但標記為過時
- 優點：保留歷史紀錄
- 缺點：可能造成混淆，增加維護負擔

### 方案 2：重構為協調器
- 將其轉換為選擇適當 sub-agent 的協調器
- 缺點：增加複雜度，違反簡單原則

## 實施時程
1. 立即：創建此 ADR
2. 第一階段：遷移有用內容到其他文件
3. 第二階段：更新所有引用
4. 第三階段：刪除 `code-generation-prompt.md`

## 相關決策
- ADR-004: Sub-agent 架構決策
- ADR-009: Command/Query/Reactor Sub-agent 分離
- ADR-031: Reactor 介面定義

## 更新紀錄
- 2025-01-15：初始決策