---
name: skill-self-contained
enabled: true
event: all
conditions:
  - field: file_path
    operator: regex_match
    pattern: ^\.dev/(comparison-test|examples)/.*\.(java|md)$
---

## ⛔ Skill 自包含原則違反！

你正在嘗試讀取 `.dev/` 目錄下的範例檔案。

### 問題
當執行 ezddd-java skill 時，發現缺少檔案（如 `BaseUseCaseTest`）後：
- ❌ **錯誤做法**：去 `.dev/comparison-test/` 或其他目錄找「參考範例」
- ✅ **正確做法**：使用 skill 內部的模板

### 正確流程

1. **先查 skill 的 templates 目錄**：
   ```
   .claude/skills/ezddd-java/references/templates/
   ```

2. **常用模板位置**：
   - `base-test-classes.md` → BaseUseCaseTest, BaseSpringBootTest
   - `aggregate-config-template.md` → Spring Config 類別
   - `local-utils.md` → DateProvider 等共用類別
   - `test-suites.md` → TestSuite 模板

3. **Skill 是自包含的**，所有產生程式碼需要的模板都在 skill 內部。

### 請改為執行

```bash
# 讀取正確的模板
Read: .claude/skills/ezddd-java/references/templates/base-test-classes.md
```
