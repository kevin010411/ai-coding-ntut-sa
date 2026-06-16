# 如何避免編碼規範違規

**建立日期**: 2025-10-01
**事件**: Sprint.java 產生時使用 if-else 而非 `Objects.equals()` 檢查 nullable 欄位
**影響**: 產生 42 行冗餘程式碼，違反 aggregate-standards.md 規範

---

## 📋 問題總結

### 發生什麼事？

在執行 `task-create-sprint` 時，aggregate-sub-agent 產生的 Sprint.java 包含以下違規程式碼：

```java
// ❌ 違規：使用 if-else 檢查 nullable 欄位（42 行）
if (goal != null) {
    ensure("Sprint goal matches input", () -> this.goal.equals(goal));
} else {
    ensure("Sprint goal is null", () -> this.goal == null);
}
// ... 重複 6 次
```

### 應該怎麼寫？

根據 `.ai/tech-stacks/java-ezddd-spring/coding-standards/aggregate-standards.md` 第 175-196 行：

```java
// ✅ 正確：使用 Objects.equals()（7 行）
ensure("Sprint goal matches input", () -> Objects.equals(goal, this.goal));
ensure("Sprint note matches input", () -> Objects.equals(note, this.note));
ensure("Sprint capacity matches input", () -> Objects.equals(capacity, this.capacity));
// ...
```

### 為什麼會發生？

**根本原因**: `.ai/tech-stacks/java-ezddd-spring/prompts/aggregate-sub-agent-prompt.md` 缺少 `Objects.equals()` 規範說明。

Sub-agent 在產生程式碼時，沒有明確的指引告訴它：
1. Nullable 欄位應該用 `Objects.equals()`
2. 不應該用 if-else 檢查
3. 這是強制規範，違反會導致 Code Review 失敗

---

## 🔧 已採取的修正措施

### 1. 修正 Sprint.java（立即修正）

**檔案**: `src/main/java/tw/teddysoft/aiscrum/sprint/entity/Sprint.java`

**修正內容**:
- 移除 42 行 if-else 檢查
- 改用 7 行 `Objects.equals()` null-safe 比較
- 程式碼減少 83%

**驗證**:
- ✅ Maven 編譯通過
- ✅ 所有測試通過（5/5）
- ✅ 符合 aggregate-standards.md 規範

### 2. 更新 aggregate-sub-agent-prompt.md（根本修正）

**檔案**: `.ai/tech-stacks/java-ezddd-spring/prompts/aggregate-sub-agent-prompt.md`

**新增內容**:
1. **強制規則清單**（第 181 行）：
   ```
   - ✅ MUST: Nullable 欄位使用 Objects.equals() 進行 null-safe 比較
   - ❌ NEVER: 使用 if-else 檢查 nullable 欄位
   ```

2. **完整規範章節**（第 191-281 行）：
   - ✅ 正確範例（使用 `Objects.equals()`）
   - ⚠️ 可接受範例（明確 null 檢查）
   - ❌ 錯誤範例（if-else，完全禁止）
   - 📋 對照表（42 行 vs 7 行）
   - 優點說明（簡潔、null-safe、減少變異點）

**效果**: 未來 aggregate-sub-agent 執行時會明確知道：
- 必須使用 `Objects.equals()`
- 絕對禁止 if-else 檢查
- 違反會導致 Code Review 失敗

---

## 🛡️ 預防機制（多層防護）

### Layer 1: Prompt 明確規範 ✅ **已實施**

**位置**: `.ai/tech-stacks/java-ezddd-spring/prompts/aggregate-sub-agent-prompt.md` 第 191-281 行

**內容**:
- 強制規則清單（MUST / NEVER）
- 正確與錯誤範例對照
- 優點說明與後果警告

**效果**: Sub-agent 產生程式碼時會優先遵循此規範

### Layer 2: Code Review Checklist ✅ **已存在**

**位置**: `.ai/tech-stacks/java-ezddd-spring/CODE-REVIEW-CHECKLIST.md`

**相關章節**: Event Sourcing 合規性檢查（第 48-156 行）

**作用**:
- Code Review 時會檢查是否使用 `Objects.equals()`
- 發現違規會標記為 MUST FIX
- 評分會降低

**限制**:
- 只在 Code Review 階段才發現
- 需要手動修正

### Layer 3: Coding Standards 文件 ✅ **已存在**

**位置**: `.ai/tech-stacks/java-ezddd-spring/coding-standards/aggregate-standards.md` 第 175-196 行

**內容**:
- 明確定義最佳實踐（`Objects.equals()`）
- 可接受做法（明確 null 檢查）
- 錯誤做法（if-else）

**作用**:
- 作為終極真相來源（Source of Truth）
- 所有 prompts 應參考此文件

### Layer 4: 自動化檢查腳本 ⚠️ **待實施**

**建議新增**: `.ai/scripts/check-nullable-comparison.sh`

**功能**:
```bash
#!/bin/bash
# 檢查 Aggregate 是否使用 if-else 檢查 nullable 欄位

# 尋找違規模式
grep -r "if.*!= null.*ensure" src/main/java/**/entity/*.java

# 如果找到，報告違規
if [ $? -eq 0 ]; then
    echo "❌ VIOLATION: Found if-else null checks in ensure statements"
    echo "Must use Objects.equals() for nullable field comparison"
    exit 1
fi

echo "✅ PASS: All nullable comparisons use Objects.equals()"
exit 0
```

**整合點**:
- `check-all.sh` 中加入此檢查
- Task 執行的 postChecks 中自動執行

### Layer 5: 範例程式碼 ✅ **已存在**

**位置**: `.ai/tech-stacks/java-ezddd-spring/examples/aggregate/Plan.java`

**內容**:
```java
ensure(format("Task deadline is '%s'", deadline),
    () -> Objects.equals(project.getTask(taskId).getDeadline(), deadline));
```

**作用**: Sub-agent 可參考正確實作

---

## 📊 預防效果評估

### 修正前（問題發生時）

| 防護層 | 狀態 | 問題 |
|--------|------|------|
| Prompt 明確規範 | ❌ 缺失 | aggregate-sub-agent-prompt.md 沒有提到 `Objects.equals()` |
| Code Review | ✅ 存在 | 但只在事後發現 |
| Coding Standards | ✅ 存在 | 但 Sub-agent 沒讀到 |
| 自動化檢查 | ❌ 無 | 沒有自動化驗證 |
| 範例程式碼 | ✅ 存在 | 但沒在 prompt 中強調 |

**結果**: Sub-agent 產生違規程式碼 → 需要手動修正

### 修正後（當前狀態）

| 防護層 | 狀態 | 改善 |
|--------|------|------|
| Prompt 明確規範 | ✅ **新增** | 明確的 MUST/NEVER 規則 + 範例對照 |
| Code Review | ✅ 存在 | 持續作為最後防線 |
| Coding Standards | ✅ 存在 | 作為 Source of Truth |
| 自動化檢查 | ⚠️ 建議 | 可選實施（進一步增強） |
| 範例程式碼 | ✅ 存在 | 在 prompt 中明確引用 |

**預期效果**:
- ✅ Sub-agent 會優先使用 `Objects.equals()`
- ✅ 即使違規，Code Review 會抓到
- ✅ （可選）自動化檢查提前發現

---

## 🎯 最佳實踐建議

### 1. Prompt 設計原則

**DO**:
- ✅ 在 prompt 中明確列出 MUST / NEVER 規則
- ✅ 提供正確與錯誤範例對照
- ✅ 說明違反規範的後果（Code Review 失敗、mutation testing 問題）
- ✅ 引用具體的規範文件行號（如 aggregate-standards.md 第 175-196 行）

**DON'T**:
- ❌ 假設 Sub-agent 會自動讀取其他文件
- ❌ 只說「參考 XXX 文件」而不提供具體規則
- ❌ 缺少範例（光說不練）

### 2. 規範文件組織

**階層架構**:
```
.ai/
├── prompts/
│   └── aggregate-sub-agent-prompt.md      ← 明確規則 + 範例
├── tech-stacks/ezddd-java/
│   ├── coding-standards/
│   │   └── aggregate-standards.md         ← Source of Truth
│   └── CODE-REVIEW-CHECKLIST.md          ← 檢查清單
└── scripts/
    └── check-nullable-comparison.sh       ← 自動化驗證（建議）
```

**同步原則**:
- coding-standards.md 是權威來源
- prompts 應該摘要關鍵規則並提供範例
- CODE-REVIEW-CHECKLIST.md 用於驗證
- scripts 提供自動化檢查

### 3. Sub-agent Workflow 改進

**建議流程**:
```
1. 讀取 prompt（含明確規則）
2. 產生程式碼
3. 自我檢查（對照 prompt 中的 MUST/NEVER）
4. （可選）執行自動化檢查腳本
5. Code Review（最後防線）
```

### 4. 持續改進機制

**當發現新的違規模式時**:

1. **立即修正**: 修正產生的程式碼
2. **分析根因**: 為什麼 Sub-agent 會產生錯誤程式碼？
3. **更新 Prompt**: 在對應的 sub-agent-prompt.md 加入規範
4. **更新 Checklist**: 確保 Code Review 會抓到
5. **考慮自動化**: 是否需要腳本自動檢查？
6. **記錄教訓**: 在 `.dev/lessons/` 建立文件

---

## 📚 相關文件索引

### 核心規範
- **Coding Standards**: `.ai/tech-stacks/java-ezddd-spring/coding-standards/aggregate-standards.md` (第 175-196 行)
- **Code Review Checklist**: `.ai/tech-stacks/java-ezddd-spring/CODE-REVIEW-CHECKLIST.md` (第 48-156 行)

### Sub-agent Prompts
- **Aggregate Sub-agent**: `.ai/tech-stacks/java-ezddd-spring/prompts/aggregate-sub-agent-prompt.md` (第 191-281 行) ← **本次更新**
- **Command Sub-agent**: `.ai/tech-stacks/java-ezddd-spring/prompts/command-sub-agent-prompt.md`

### 範例程式碼
- **Plan.java**: `.ai/tech-stacks/java-ezddd-spring/examples/aggregate/Plan.java` (第 338, 344 行)
- **Sprint.java**: `src/main/java/tw/teddysoft/aiscrum/sprint/entity/Sprint.java` (第 100-106 行) ← **本次修正**

### Code Review
- **本次 Task Review**: `.dev/reports/task-create-sprint-review.md` (發現問題但未標記為 MUST FIX)
- **Aggregate Code Review Prompt**: `.ai/tech-stacks/java-ezddd-spring/prompts/aggregate-code-review-prompt.md` (第 164-231 行)

---

## 💡 總結

### 問題

Sub-agent 產生的程式碼違反編碼規範（使用 if-else 而非 `Objects.equals()`），因為 prompt 中缺少明確指引。

### 解決方案

1. ✅ **立即修正**: 修正 Sprint.java（42 行 → 7 行）
2. ✅ **根本修正**: 更新 aggregate-sub-agent-prompt.md，加入完整的 `Objects.equals()` 規範章節
3. ⚠️ **可選強化**: 實作自動化檢查腳本

### 預防機制（5 層防護）

1. **Prompt 明確規範** ← ✅ 本次更新（主要防線）
2. **Code Review Checklist** ← ✅ 已存在（次要防線）
3. **Coding Standards 文件** ← ✅ 已存在（真相來源）
4. **自動化檢查腳本** ← ⚠️ 建議實施（增強防線）
5. **範例程式碼** ← ✅ 已存在（參考實作）

### 未來影響

✅ **下次執行 aggregate-sub-agent 時**:
- Sub-agent 會讀到明確的 MUST/NEVER 規則
- 會看到正確與錯誤範例對照
- 應該會直接產生正確的 `Objects.equals()` 程式碼
- 即使違規，Code Review 也會抓到

### 最重要的教訓

> **Prompt 必須明確、具體、有範例**
>
> 不能假設 Sub-agent 會自動閱讀其他文件，必須在 prompt 中直接提供：
> 1. 明確的 MUST / NEVER 規則
> 2. 正確與錯誤範例對照
> 3. 違反後果說明
> 4. 引用權威文件位置

---

**建立者**: Claude Code
**最後更新**: 2025-10-01
**狀態**: ✅ 已修正並建立預防機制
