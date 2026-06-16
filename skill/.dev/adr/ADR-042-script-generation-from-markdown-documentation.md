# ADR-042: Script Generation from Markdown Documentation

## Status
Accepted

## Context
我們的專案有兩種重要的文件需要維護：
1. **Coding Standards 文件** (`.md` 格式) - 給開發人員閱讀的規範文件
2. **檢查腳本** (`.sh` 格式) - 自動化檢查程式碼是否符合規範

原本的問題：
- 檢查腳本的規則是寫死的（hardcoded）
- 當 Coding Standards 文件更新時，檢查腳本不會自動更新
- 需要維護兩份資訊：文件和腳本
- 可能出現文件與檢查邏輯不同步的問題

## Decision
**直接從 Coding Standards Markdown 文件自動生成檢查腳本**

實作方式：
1. 使用 `generate-check-scripts-from-md.sh` 解析 Markdown 文件
2. 識別 `// ✅ 正確` 和 `// ❌ 錯誤` 的程式碼範例
3. 提取規則並生成對應的 Shell 檢查腳本
4. 檢查腳本存放在 `generated/` 目錄
5. 使用符號連結保持向後相容性

## Consequences

### 好處
1. **Single Source of Truth** - Markdown 文件是唯一的規則來源
2. **自動同步** - 文件更新後重新生成即可，無需手動同步
3. **減少維護成本** - 只需維護一份文件
4. **透明度高** - 看文件就知道會檢查什麼
5. **版本控制友好** - 文件變更即規則變更，易於追蹤

### 壞處
1. **依賴文件格式** - 需要保持 Markdown 格式的一致性
2. **解析限制** - 複雜的檢查邏輯可能難以從文件自動提取
3. **需要重新生成** - 文件更新後需要執行生成器

### 中立
1. 不是所有腳本都從 .md 生成 - 工具類腳本仍然手動維護
2. 需要 Python 環境來執行解析器

## Implementation Details

### 檔案結構
```
.ai/tech-stacks/java-ezddd-spring/coding-standards/
├── repository-standards.md    # 源文件
├── mapper-standards.md        # 源文件
└── ...

.ai/scripts/
├── generate-check-scripts-from-md.sh  # 生成器
├── parse-md-rules.py                  # 解析器（自動生成）
├── generated/                          # 生成的腳本
│   ├── check-repository.sh
│   └── check-mapper.sh
└── check-*-compliance.sh              # 符號連結（相容性）
```

### 使用方式
```bash
# 生成檢查腳本
./generate-check-scripts-from-md.sh

# 執行檢查
./generated/check-repository.sh
```

### 關鍵標記
- `// ❌ 錯誤：` - 標記不應該存在的模式
- `// ✅ 正確：` - 標記應該存在的模式
- `## 🔴 必須遵守的規則` - 標記重要規則區塊

## Alternatives Considered

### Alternative 1: YAML 規則檔案
- 維護獨立的 YAML 檔案定義規則
- 優點：更精確的控制，支援複雜邏輯
- 缺點：需要維護兩份文件，可能不同步
- **拒絕原因**：違反 Single Source of Truth 原則

### Alternative 2: 手動維護檢查腳本
- 繼續手動編寫和維護檢查腳本
- 優點：完全控制，不依賴解析器
- 缺點：容易與文件不同步，維護成本高
- **拒絕原因**：維護負擔大，容易出錯

### Alternative 3: 在文件中嵌入可執行程式碼
- 在 Markdown 中直接嵌入 Shell 腳本
- 優點：文件即程式碼
- 缺點：降低文件可讀性，混合關注點
- **拒絕原因**：破壞文件的主要用途（人類閱讀）

## References
- [MD-SCRIPT-GENERATION-GUIDE.md](../../.ai/scripts/MD-SCRIPT-GENERATION-GUIDE.md)
- [Coding Standards](../../.ai/tech-stacks/java-ezddd-spring/coding-standards.md)
- Related ADRs:
  - ADR-005: AI Task 執行 SOP
  - ADR-013: Task Results Tracking

## Notes
- 2025-09-02: 初始決策，實作從 Markdown 生成檢查腳本的系統
- 這個決策確保了文件與檢查邏輯的一致性，是朝向「文件即規範」的重要一步