# ADR-021: 強制要求所有 Modal 視窗可拖動

## 狀態
已採納 (Accepted)

## 背景
在使用者測試中發現，固定位置的 Modal 視窗會遮擋背景內容，使用者需要關閉 Modal 才能查看被遮擋的資訊。這種體驗在需要參考背景資訊來填寫表單或查看詳情時特別不便。

## 決策
從 2025-08-20 起，所有前端的 Modal 視窗都必須實作可拖動功能。

### 實作要求
1. **統一使用 DraggableModal 元件**
   - 所有 Modal 必須使用 `/frontend/src/components/DraggableModal.tsx` 元件
   - 不允許直接實作固定位置的 Modal

2. **拖動行為規範**
   - 只有標題欄可以拖動（避免干擾內容操作）
   - 標題欄顯示移動圖標（Move icon）作為視覺提示
   - 拖動時游標變化：`cursor-move` → `cursor-grabbing`

3. **功能要求**
   - ESC 鍵關閉
   - 點擊背景遮罩關閉
   - 關閉按鈕正常運作
   - 每次開啟時位置重置到中央

## 後果

### 正面影響
- **改善使用者體驗**：使用者可以移動 Modal 查看被遮擋的內容
- **提高工作效率**：無需頻繁開關 Modal 即可參考背景資訊
- **統一實作**：所有 Modal 行為一致，降低學習成本
- **減少重複程式碼**：統一使用 DraggableModal 元件

### 負面影響
- **開發成本**：需要重構現有的 Modal 元件
- **測試工作**：需要測試拖動功能在不同瀏覽器的相容性
- **效能考量**：拖動事件處理可能略微增加 CPU 使用

## 實作範例

### 正確實作
```typescript
import DraggableModal from '@/components/DraggableModal';

const MyModal: React.FC<Props> = ({ isOpen, onClose }) => {
  return (
    <DraggableModal
      isOpen={isOpen}
      onClose={onClose}
      title="變更重要性"
      width="max-w-md"
    >
      <form>
        {/* Modal 內容 */}
      </form>
    </DraggableModal>
  );
};
```

### 錯誤實作
```typescript
// ❌ 不要直接實作固定位置的 Modal
const BadModal: React.FC<Props> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;
  
  return (
    <div className="fixed inset-0 z-50">
      <div className="fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
        {/* Modal 內容 */}
      </div>
    </div>
  );
};
```

## 相關文件
- `/frontend/src/components/DraggableModal.tsx` - 可拖動 Modal 元件實作
- `/.ai/tech-stacks/frontend-react-typescript/coding-standards.md` - 前端編碼標準
- `/.ai/tech-stacks/frontend-react-typescript/code-review-checklist.md` - 程式碼審查清單

## 已更新的 Modal 元件
- `ChangeImportanceModal` - ✅ 已更新
- `EstimatePbiModal` - ✅ 已更新
- 待更新：
  - `RenamePbiModal`
  - `ChangeDescriptionModal`
  - `SetAcceptanceCriteriaModal`
  - `ViewPbiDetailModal`
  - `ProductBacklogSelectorModal`
  - `ConfirmationModal`
  - 其他 Modal 元件

## 決策者
- 日期：2025-08-20
- 決策原因：使用者體驗改善需求
- 參與者：前端開發團隊