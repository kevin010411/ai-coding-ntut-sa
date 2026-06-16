# ADR-014: 在 @dnd-kit 拖放元件中處理點擊事件

## 狀態
已採納

## 日期
2025-08-18

## 背景
在 Scrum Board 頁面中，我們需要在可拖動的 PBI 卡片上添加一個「查看詳情」按鈕。但是遇到了一個常見問題：當整個卡片都是可拖動區域時，@dnd-kit 的拖動監聽器會攔截所有的點擊事件，導致按鈕無法被點擊。

### 問題描述
- PBI 卡片使用 @dnd-kit/sortable 的 `useSortable` hook
- `listeners` 包含 `onPointerDown` 事件來啟動拖動
- 當 `listeners` 應用到整個卡片時，所有子元素的點擊事件都會被攔截
- 即使使用 `e.stopPropagation()` 在 `onClick` 也無效，因為 `onPointerDown` 先觸發

### 嘗試過但失敗的方案
1. **在按鈕的 onClick 使用 stopPropagation** - 無效，因為 pointer 事件先觸發
2. **使用 onMouseDown 阻止傳播** - 無效，@dnd-kit 使用 pointer 事件
3. **設置高 z-index** - 無效，事件傳播與 z-index 無關
4. **將按鈕放在拖動區域外** - 可行但破壞了 UI 設計

## 決策

### 採用方案：在按鈕上阻止 onPointerDown 事件傳播

```tsx
<button
  type="button"
  className="absolute top-2 left-2 z-50 ..."
  onPointerDown={(e) => {
    e.stopPropagation();  // 關鍵：阻止 @dnd-kit 的拖動啟動
  }}
  onClick={(e) => {
    e.stopPropagation();
    onViewDetails();
  }}
>
  <InformationCircleIcon className="w-5 h-5" />
</button>
```

### 原理
- @dnd-kit 使用 `onPointerDown` 來啟動拖動
- 在按鈕上阻止 `onPointerDown` 的傳播，就能防止該區域觸發拖動
- 但 `onClick` 事件仍然可以正常工作
- 卡片的其他區域仍然可以正常拖動

## 影響

### 正面
- ✅ 保持整張卡片都可拖動的使用者體驗
- ✅ 按鈕可以正常點擊，不會觸發拖動
- ✅ 不需要修改拖動邏輯或創建特定的拖動手柄
- ✅ 程式碼簡潔，易於理解和維護

### 負面
- ⚠️ 需要記住在所有可點擊元素上都要加上 `onPointerDown` 處理
- ⚠️ 如果忘記加上，按鈕將無法點擊

## 實作指引

### 在拖動元件中添加可點擊按鈕的標準模式：

```tsx
const DraggableCard = ({ onAction }) => {
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id });
  
  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      {...attributes}
      {...listeners}  // 這會添加 onPointerDown 等事件
    >
      {/* 可點擊的按鈕 */}
      <button
        onPointerDown={(e) => e.stopPropagation()}  // 必須！
        onClick={(e) => {
          e.stopPropagation();
          onAction();
        }}
      >
        Click Me
      </button>
      
      {/* 卡片其他內容 */}
    </div>
  );
};
```

### 注意事項
1. **必須使用 onPointerDown**，不是 onMouseDown
2. **同時在 onClick 也要 stopPropagation** 避免事件冒泡
3. **如果有多層嵌套**，每一層都要處理

## 參考資料
- [@dnd-kit 官方文檔](https://docs.dndkit.com/)
- [Pointer Events MDN](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events)
- 實作檔案：`/frontend/src/pages/ScrumBoardWithSwimlanes.tsx`

## 結論
這個模式成功解決了在拖放元件中添加可點擊元素的常見問題，應該作為專案中處理類似情況的標準方法。