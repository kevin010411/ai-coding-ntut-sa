# Spec 檔案組織指南

> 此指南說明如何正確組織 spec 檔案，以反映領域模型的 Aggregate 邊界。

## 📁 目錄結構原則

### ✅ 正確結構
```
.dev/specs/
├── product/              # Product Aggregate
│   ├── entity/          # Product 領域模型規格
│   │   └── product-spec.md
│   └── usecase/         # Product 相關 Use Cases
│       ├── create-product.json
│       ├── set-product-goal.json
│       └── add-product-goal-metric.json
│
├── pbi/                  # ProductBacklogItem Aggregate
│   ├── entity/          # PBI 領域模型規格
│   │   └── pbi-spec.md
│   └── usecase/         # PBI 相關 Use Cases
│       ├── create-pbi.json
│       ├── estimate-pbi.json
│       └── move-pbi-to-sprint.json
│
├── sprint/               # Sprint Aggregate
│   ├── entity/
│   │   └── sprint-spec.md
│   └── usecase/
│       ├── create-sprint.json
│       └── start-sprint.json
│
├── team/                 # Team Aggregate
│   ├── entity/
│   └── usecase/
│
└── tag/                  # Tag Aggregate
    ├── entity/
    └── usecase/
        └── tag-crud.md
```

### ❌ 錯誤結構
```
.dev/specs/
└── product/
    └── usecase/
        ├── create-product.json
        ├── create-pbi.json        ❌ PBI 不應在 product 下
        └── create-sprint.json     ❌ Sprint 不應在 product 下
```

## 🎯 判斷 Spec 應該放在哪裡

### 步驟 1：識別主要 Aggregate
問自己：「這個 Use Case 主要操作哪個 Aggregate？」

### 步驟 2：檢查 Aggregate 名稱
- `CreateProduct` → Product Aggregate → `product/usecase/`
- `CreateProductBacklogItem` → PBI Aggregate → `pbi/usecase/`
- `CreateSprint` → Sprint Aggregate → `sprint/usecase/`

### 步驟 3：驗證決定
使用 [AGGREGATE-IDENTIFICATION-CHECKLIST.md](../../.ai/tech-stacks/java-ezddd-spring/checklists/AGGREGATE-IDENTIFICATION-CHECKLIST.md)

## 📝 命名規範

### Use Case Spec 檔案
- 格式：`[action]-[aggregate].json`
- 範例：
  - `create-product.json`
  - `create-pbi.json`（不是 create-product-backlog-item.json）
  - `estimate-pbi.json`

### Entity Spec 檔案
- 格式：`[aggregate]-spec.md`
- 範例：
  - `product-spec.md`
  - `pbi-spec.md`
  - `sprint-spec.md`

## ⚠️ 常見錯誤

### 錯誤 1：根據關聯關係組織
```
❌ product/usecase/create-pbi.json
   理由：雖然 PBI 有 ProductId，但 PBI 是獨立 Aggregate
   
✅ pbi/usecase/create-pbi.json
```

### 錯誤 2：根據名稱前綴組織
```
❌ product/usecase/create-product-backlog-item.json
   理由：名稱誤導，PBI 不是 Product 的一部分
   
✅ pbi/usecase/create-pbi.json
```

### 錯誤 3：集中式組織
```
❌ specs/usecases/create-product.json
❌ specs/usecases/create-pbi.json
   理由：失去 Aggregate 邊界的可見性
   
✅ specs/product/usecase/create-product.json
✅ specs/pbi/usecase/create-pbi.json
```

## 🔄 遷移指南

如果發現 spec 檔案位置錯誤：

1. **創建正確的目錄結構**
   ```bash
   mkdir -p .dev/specs/[aggregate]/usecase
   ```

2. **移動檔案**
   ```bash
   mv .dev/specs/product/usecase/create-sprint.json \
      .dev/specs/pbi/usecase/
   ```

3. **更新相關引用**
   - task-*.json 中的 spec.useCase 路徑
   - 測試檔案中的引用
   - 文檔中的連結

4. **驗證**
   ```bash
   # 確認沒有遺漏的引用
   grep -r "product/usecase/create-pbi" .
   ```

## 📊 Aggregate 對照表

| Aggregate | Spec 目錄 | 主要 Use Cases |
|-----------|----------|----------------|
| Product | `product/` | CreateProduct, SetProductGoal |
| ProductBacklogItem | `pbi/` | CreatePBI, EstimatePBI, AssignPBI |
| Sprint | `sprint/` | CreateSprint, StartSprint, CloseSprint |
| Team | `team/` | CreateTeam, AddMember, RemoveMember |
| Tag | `tag/` | CreateTag, DeleteTag, AssignTag |

## 🚀 最佳實踐

1. **新增 Spec 前先確認 Aggregate**
   - 查看 [DOMAIN-MODEL.md](../../.ai/DOMAIN-MODEL.md)
   - 使用 [AGGREGATE-IDENTIFICATION-CHECKLIST.md](../../.ai/tech-stacks/java-ezddd-spring/checklists/AGGREGATE-IDENTIFICATION-CHECKLIST.md)

2. **保持一致性**
   - Spec 結構應與程式碼套件結構一致
   - 命名應與領域術語一致

3. **定期審查**
   - Code Review 時檢查 spec 位置
   - 發現錯誤立即修正

## 📅 更新記錄

- **2025-08-12**: 初始版本，建立 spec 組織原則
- **2025-08-12**: 將 create-pbi.json 從 product/ 移至 pbi/