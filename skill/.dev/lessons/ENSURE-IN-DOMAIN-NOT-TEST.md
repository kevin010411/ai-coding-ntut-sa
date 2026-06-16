# Lesson Learned: ensure() 後置條件必須在 Domain Layer

**日期**: 2024-12-22
**問題**: CopyLane Use Case 的 nested children 驗證

---

## 錯誤描述

實作 `Workflow.copyLane()` 時，遇到 InMemory repository event replay 問題，
導致從 repository 取回後 children 數量為 0。

**錯誤決策**：把 nested children 驗證從 Domain Layer 移到 Test Layer。

---

## 根本原因

1. **不理解 `ensure()` 執行時機**
   - `ensure()` 在 `apply()` 後**立即**執行
   - 此時狀態還在記憶體中，不受 repository 影響

2. **遇到困難時選擇「繞過」而非「解決」**
   - 正確做法：找出 ensure() 的正確執行時機
   - 錯誤做法：把驗證移到測試層

3. **混淆職責**
   - `ensure()` = 方法的「承諾」（契約）
   - `assertThat()` = 驗證契約是否正確實作

---

## 正確做法

```java
public LaneId copyLane(LaneId sourceLaneId, ...) {
    // 1. 在 apply() 前捕獲舊狀態
    final int sourceChildCount = sourceLane.getChildCount();

    // 2. 執行狀態變更
    apply(new LaneCopied(...));

    // 3. 在 apply() 後立即用 ensure() 驗證（狀態還在記憶體中）
    Lane copiedLane = lanes.get(copiedLaneId);
    ensure("Copied lane has same children count",
        () -> copiedLane.getChildCount() == sourceChildCount);
}
```

---

## 職責分離

| 層級 | 職責 | 工具 |
|------|------|------|
| Domain Layer | 保證方法的後置條件成立 | `ensure()` |
| Test Layer | 驗證 Use Case 流程正確 | `assertThat()` |

---

## 預防措施

1. **Code Review Checklist** 已更新
   - 新增「Design by Contract - ensure() 後置條件」檢查項目
   - 位置：`.ai/tech-stacks/java-ezddd-spring/CODE-REVIEW-CHECKLIST.md`

2. **關鍵問題**（Code Review 時必問）
   - 這個方法的「承諾」是什麼？
   - 這些「承諾」有沒有用 `ensure()` 驗證？
   - `ensure()` 是在 `apply()` 後立即執行嗎？

---

## 記住

> **`ensure()` 在 `apply()` 後立即執行，狀態還在記憶體中。**
> **方法的「承諾」用 `ensure()`，測試只是驗證契約是否正確實作。**
