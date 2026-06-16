# Code Reviewer (ezddd-java)

## Overview

針對 DDD + Clean Architecture + Event Sourcing 專案的系統化 Code Review。

## File Structure

```
references/code-reviewer/
├── README.md                  ← 本檔案
├── checklist.md               ← 完整檢查清單（按檔案類型）
├── workflow.md                ← 執行流程（Default + Multi-Model）
├── aggregate-review.md        ← Aggregate 完整審查模式
└── must-fail-conditions.md    ← 必須失敗的條件清單
```

## Execution Modes

| Mode | Command | Models | Speed | Accuracy |
|------|---------|--------|-------|----------|
| **Default** | `/code-review Sprint.java` | Claude only | ~30 秒 | ⭐⭐⭐ |
| **Multi-Model** | `/code-review Sprint.java --multi` | 4 LLMs | ~2 分鐘 | ⭐⭐⭐⭐⭐ |

## When to Use --multi

- 關鍵檔案審查（Aggregate Root, Domain Events）
- 發布前最終檢查
- 需要高可信度的審查結果
- 複雜業務邏輯驗證

## Quick Start

### Default Mode
```
1. 識別檔案類型 → checklist.md
2. 讀取對應 checklist section
3. 讀取目標檔案
4. 執行測試（如適用）
5. 建立檢查對照表
6. 產生報告
```

### Multi-Model Mode (--multi)
```
1. 準備 prompt（包含 checklist + 檔案內容）
2. 平行呼叫 4 個 LLM（Claude, Gemini, ChatGPT, Codex）
3. 收集結果並計算共識
4. Claude 仲裁爭議項目
5. 產生共識報告
```

## File Type Priority

| Priority | File Types | Key Checks |
|----------|------------|------------|
| **CRITICAL** | Aggregate Root, Domain Events | Event Sourcing 合規性 |
| **HIGH** | Value Object ID, UseCase Service | 套件位置、編碼規範 |
| **MEDIUM** | Entity, Controller, Test | 設計模式、測試規範 |
| **LOW** | Mapper, Config | 實作細節 |

## Related Files

- `references/patterns/domain/aggregate.md` - Aggregate 設計規範
- `references/patterns/domain/domain-event.md` - Domain Event 規範
- `references/rules/common-rules.md` - 通用規則
