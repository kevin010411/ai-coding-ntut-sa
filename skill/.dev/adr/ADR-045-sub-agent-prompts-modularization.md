# ADR-045: Sub-agent Prompts 模組化架構

## 狀態
接受 (Accepted)

## 日期
2025-09-15

## 背景
Sub-agent prompts 中存在大量重複內容，造成以下問題：
1. **維護困難**：修改規則需要更新多個檔案
2. **版本不一致**：ProfileSetter pattern 在三個地方有不同版本
3. **檔案過大**：command-sub-agent-prompt.md 超過 750 行
4. **重複程式碼**：Fresh Project Initialization 在多個 sub-agent 中重複

## 決策
將 sub-agent prompts 重構為模組化架構，抽離共用內容到獨立檔案。

### 架構設計
```
.ai/tech-stacks/java-ezddd-spring/prompts/
├── shared/                      # 共用模組目錄
│   ├── common-rules.md         # 所有 sub-agent 共用規則
│   ├── fresh-project-init.md   # 專案初始化步驟
│   ├── dual-profile-testing.md # ProfileSetter pattern 配置
│   ├── mandatory-references.md # 必讀文件清單
│   └── architecture-config.md  # 架構配置讀取邏輯
└── *-sub-agent-prompt.md       # 各 sub-agent 引用共用模組
```

### 引用機制
Sub-agent prompts 使用 Markdown 連結引用共用內容：
```markdown
**See [Common Rules](./shared/common-rules.md) for all sub-agent shared rules.**
```

## 實施結果

### 量化成效
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Total Lines | 1735 | 1316 | -24.2% |
| command-sub-agent | 755 | 530 | -29.8% |
| query-sub-agent | 580 | 486 | -16.2% |
| reactor-sub-agent | 400 | 300 | -25.0% |

### 質化改進
1. **ProfileSetter Pattern 統一**：從 3 個版本統一為 1 個
2. **Fresh Project Init 集中**：不再分散在多個檔案
3. **規則單點維護**：修改規則只需更新 common-rules.md
4. **文件路徑管理**：所有路徑集中在 mandatory-references.md

## 影響範圍

### 受影響的檔案
- ✅ command-sub-agent-prompt.md
- ✅ query-sub-agent-prompt.md
- ✅ reactor-sub-agent-prompt.md
- ✅ CLAUDE.md (更新說明)

### 未修改的檔案（有獨特內容）
- aggregate-sub-agent-prompt.md
- outbox-sub-agent-prompt.md
- profile-config-sub-agent-prompt.md
- ezspec-test-generation-prompt.md

## 後續建議

### 短期
1. 監控 sub-agent 使用情況，確認引用機制正常運作
2. 檢查其他 sub-agent 是否也能受益於模組化

### 長期
1. 考慮建立 sub-agent prompt 模板生成器
2. 建立自動化檢查，防止重複內容再次出現
3. 評估是否需要更細粒度的模組劃分

## 風險與緩解

### 風險
1. **引用路徑錯誤**：相對路徑可能因檔案移動而失效
2. **模組過度拆分**：可能造成理解困難

### 緩解措施
1. 使用相對路徑 `./shared/` 確保可攜性
2. 保持模組在合理大小，避免過度細分
3. 在 CLAUDE.md 中記錄模組架構

## 決策理由
1. **DRY 原則**：Don't Repeat Yourself
2. **單一職責**：每個模組負責特定領域
3. **維護性優先**：降低維護成本比檔案數量更重要
4. **漸進式改進**：先處理最嚴重的重複，後續再優化

## 參考資料
- [Sub-agent System Documentation](.ai/tech-stacks/java-ezddd-spring/SUB-AGENT-SYSTEM.md)
- [Common Rules](../../.ai/tech-stacks/java-ezddd-spring/prompts/shared/common-rules.md)
- [Dual Profile Testing](../../.ai/tech-stacks/java-ezddd-spring/prompts/shared/dual-profile-testing.md)