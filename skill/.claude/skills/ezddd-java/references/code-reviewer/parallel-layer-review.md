# Parallel Layer Review Workflow

## Overview

按 Clean Architecture 層級平行審查多個檔案。適用於大型 PR 或一次產生多個檔案的 UC Executor 執行結果。

```
已有模式:
  - 單檔 review (workflow.md)     → 1 file × 1 reviewer × 7 steps
  - 多模型 review (--multi)       → 1 file × 4 models (parallel)

本 workflow:
  - 平行層級 review (--parallel)  → N files × M layers (parallel)
```

## Trigger

用戶輸入以下關鍵字時啟用：
- `review pr` / `review PR #123`
- `review all changes` / `review 所有變更`
- `parallel review` / `平行 review`
- `review --parallel`

## Execution Model

```
Phase 0: File Classification (sequential, < 5 seconds)
  └── git diff → classify by layer → assign to agents

Phase 1: Layer Review (PARALLEL, 3-5 agents)
  ├── Domain Agent     → entity/*.java, *Events.java, *Id.java
  ├── UseCase Agent    → usecase/**/*.java
  ├── Infra Agent      → adapter/**/*.java, config/*.java, *OrmClient.java
  └── Test Agent       → *Test.java, *ContractTest.java

Phase 2: Cross-Layer Check (sequential, main agent)
  └── Verify layer boundaries + aggregate report

Phase 3: Final Report (sequential)
  └── Merge all findings → rating → output
```

## Conflict Analysis

| 操作 | 衝突風險 | 原因 |
|------|---------|------|
| 多個 agent 同時讀檔 | 無 | 只讀操作 |
| 多個 agent 同時寫報告 | 無 | 各自寫入不同檔案 |
| Cross-layer 依賴檢查 | 無 | Phase 2 才做，Phase 1 已完成 |

**這是最安全的平行化場景 — 完全只讀，零衝突風險。**

---

## Phase 0: File Classification

### Step 0.1: Collect Changed Files

```bash
# PR review
gh pr diff {PR_NUMBER} --name-only

# Local changes (unstaged + staged)
git diff --name-only HEAD

# Compare with main
git diff --name-only main...HEAD
```

### Step 0.2: Classify by Layer

使用 checklist.md 的 File Type Identification 表，將檔案分配到層級：

| Layer | File Patterns | Checklist Section |
|-------|--------------|-------------------|
| **domain** | `**/entity/{Aggregate}.java`, `**/entity/*Events.java`, `**/entity/*Id.java`, `**/entity/*.java` | Aggregate Root / Domain Event / Value Object |
| **usecase** | `**/usecase/service/*.java`, `**/usecase/port/in/*.java`, `**/usecase/port/*Mapper.java` | Use Case Service / Interface / Mapper |
| **infra** | `**/adapter/**/*.java`, `**/io/springboot/config/*.java`, `**/*OrmClient.java`, `**/*Data.java` | Controller / Repository Config / ORM Client |
| **test** | `**/*Test.java`, `**/*ContractTest.java` | Test / Contract Test |

### Step 0.3: Skip Criteria

跳過不需要 review 的檔案：

| Pattern | 原因 |
|---------|------|
| `*State.java` (enum) | LOW priority, trivial |
| `**/test/suite/**` | TestSuite 配置，非業務邏輯 |
| `application*.properties` | 配置檔，非程式碼 |
| `pom.xml` | 依賴管理，非業務邏輯 |

### Step 0.4: Decide Execution Mode

| 檔案數量 | 建議模式 |
|---------|---------|
| 1-2 files | 不需要平行，直接用 workflow.md 逐一 review |
| 3-8 files | 平行 layer review（本 workflow） |
| 9+ files | 平行 layer review + 考慮分批 |
| 只有同一層 | 不需要跨層平行，單層內串行 review |

---

## Phase 1: Parallel Layer Review

### Agent Prompt Template

每個 layer agent 收到以下 prompt:

```
你是 {layer_name} 層的 Code Reviewer。

## 你的職責
只審查 {layer_name} 層的檔案，使用以下 checklist 章節：
{checklist_sections}

## 你要審查的檔案
{file_list_with_paths}

## 執行步驟
1. 讀取 checklist.md 中的 "{checklist_section}" 章節
2. 逐一讀取每個檔案
3. 對每個檔案執行 checklist 檢查
4. 產生結構化結果

## 輸出格式
對每個檔案回傳：

### {filename}
| Check Item | Result | Line | Issue |
|------------|--------|------|-------|
| ... | PASS/FAIL | ... | ... |

Summary: X critical, Y must-fix, Z should-fix
Rating: N/5 stars
```

### Launch Agents

使用 Task tool 平行啟動（**一個 message 中發出所有 Task calls**）：

```javascript
// 同時啟動所有 layer agents
Task({
  description: "Review domain layer",
  subagent_type: "general-purpose",
  model: "sonnet",           // sonnet 足夠，省成本
  run_in_background: true,
  prompt: `[Domain Agent Prompt with file list]`
})

Task({
  description: "Review usecase layer",
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  prompt: `[UseCase Agent Prompt with file list]`
})

Task({
  description: "Review infra layer",
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  prompt: `[Infra Agent Prompt with file list]`
})

Task({
  description: "Review test layer",
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: true,
  prompt: `[Test Agent Prompt with file list]`
})
```

### Layer-Specific Focus

| Layer Agent | Primary Checks | Secondary Checks |
|-------------|---------------|-----------------|
| **Domain** | Event Sourcing compliance, DBC contracts, state in when() only | Semantics vocabulary, metadata in events |
| **UseCase** | Input/Output as inner class, no @Component, YAGNI | Mapper completeness, command/query separation |
| **Infra** | Package location, bean naming, profile isolation | CORS, REST conventions, error response format |
| **Test** | Dual-profile compliance, @DirtiesContext, ezSpec usage | Contract test coverage, postcondition verification |

---

## Phase 2: Cross-Layer Checks

Phase 1 完成後，主 agent 執行跨層驗證（這些是單一 agent 無法檢查的）：

| Cross-Layer Check | 說明 |
|-------------------|------|
| **Domain ← UseCase** | UseCase 是否正確使用 Domain 的 public API？ |
| **UseCase ← Controller** | Controller 的 Input 是否與 UseCase.Input 一致？ |
| **Domain ↔ Test** | 每個 Domain method 是否有對應的 Contract Test？ |
| **Entity ↔ Events** | 每個 apply(event) 是否有對應的 when(event) handler？ |
| **Config ↔ UseCase** | UseCaseConfig 是否為每個 UseCase Service 提供 @Bean？ |

### Cross-Layer Check Execution

```
1. 從 Domain Agent 結果取得 public methods 列表
2. 從 Test Agent 結果取得 tested methods 列表
3. 比對：有 method 沒被測到 → GAP
4. 從 UseCase Agent 結果取得 Input/Output 型別
5. 從 Infra Agent 結果取得 Controller request/response 型別
6. 比對：型別不一致 → MISMATCH
```

---

## Phase 3: Final Report

### Report Structure

```markdown
## Parallel Layer Review Report

### Overview
- PR/Branch: {identifier}
- Files Reviewed: {total_count}
- Agents Used: {agent_count}
- Total Wall-Clock Time: {time} (vs sequential estimate: {sequential_time})

### Per-Layer Summary

| Layer | Files | Critical | Must Fix | Should Fix | Rating |
|-------|-------|----------|----------|------------|--------|
| Domain | 3 | 0 | 1 | 2 | ⭐⭐⭐⭐ |
| UseCase | 2 | 0 | 0 | 1 | ⭐⭐⭐⭐⭐ |
| Infra | 4 | 0 | 2 | 0 | ⭐⭐⭐⭐ |
| Test | 3 | 1 | 0 | 1 | ⭐⭐⭐ |
| **Total** | **12** | **1** | **3** | **4** | **⭐⭐⭐** |

### Cross-Layer Issues
| Check | Status | Details |
|-------|--------|---------|
| Domain ↔ Test coverage | ⚠️ GAP | `Sprint.cancel()` has no ContractTest |
| UseCase ↔ Controller types | ✅ OK | All Input/Output types match |

### Critical Issues (Blocking)
1. [Layer: Test] Missing @DirtiesContext on CreateSprintServiceTest (line 15)
   - Impact: Test isolation failure, flaky tests
   - Fix: Add `@DirtiesContext(classMode = AFTER_EACH_TEST_METHOD)`

### Must Fix Issues
...

### Overall Rating: ⭐⭐⭐ (3/5)
- Rating = min(all layer ratings)
- Blocking issues: 1 (must resolve before merge)
```

### Rating Calculation

```
Overall Rating = min(domain_rating, usecase_rating, infra_rating, test_rating)
```

最低分的層決定整體評分。一個 CRITICAL issue 就會把該層拉到 ⭐ (1/5)。

---

## Performance Estimate

| Scenario | Sequential | Parallel (this workflow) | Speedup |
|----------|-----------|------------------------|---------|
| 4 files, 4 layers | ~8 min | ~2.5 min | 3.2x |
| 8 files, 4 layers | ~16 min | ~5 min | 3.2x |
| 12 files, 5 layers | ~24 min | ~6 min | 4.0x |

Speedup ≈ number of layers with files (bounded by slowest layer).

---

## Combining with Other Modes

本 workflow 可以與其他 review 模式組合：

```
# 平行層級 + 嚴格模式（每個 agent 內部用 7 步驟）
review --parallel --strict

# 平行層級 + IntelliJ L0 檢查（先跑 L0，再平行 L1）
review --parallel --intellij

# 平行層級中的 Domain 層額外用多模型審查
review --parallel --multi=domain
```

### Combined Mode: --parallel --intellij

```
Phase 0: Classification
Phase 0.5: IntelliJ L0 (sequential, all files)
  └── mcp__intellij-idea__get_file_problems for each .java file
  └── If any ERROR → stop, report, and request fix
Phase 1: Parallel L1 Layer Review (as above)
Phase 2: Cross-Layer Check
Phase 3: Final Report (L0 + L1 merged)
```
