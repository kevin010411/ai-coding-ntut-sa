# ADR-015: 可拖動 Modal 視窗設計模式

## 狀態
已採納

## 日期
2025-08-18

## 背景
在複雜的 Web 應用中，Modal 視窗經常用於顯示詳細資訊。但固定位置的 Modal 可能會遮擋使用者想要參考的內容。為了提升使用體驗，我們需要：
1. 讓使用者能夠移動 Modal 到適合的位置
2. 提供快速關閉的鍵盤快捷鍵
3. 保持良好的視覺提示和互動體驗

## 決策

### 1. 拖動功能實作
使用 React Hooks 和原生滑鼠事件實作拖動功能：

```typescript
const [position, setPosition] = useState({ x: 0, y: 0 });
const [isDragging, setIsDragging] = useState(false);
const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

// 拖動開始
const handleMouseDown = (e: React.MouseEvent) => {
  setIsDragging(true);
  setDragStart({
    x: e.clientX - position.x,
    y: e.clientY - position.y
  });
};

// 拖動中和結束
useEffect(() => {
  const handleMouseMove = (e: MouseEvent) => {
    if (isDragging) {
      setPosition({
        x: e.clientX - dragStart.x,
        y: e.clientY - dragStart.y
      });
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  if (isDragging) {
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }

  return () => {
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  };
}, [isDragging, dragStart]);
```

### 2. ESC 鍵關閉功能
```typescript
useEffect(() => {
  const handleEscKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape' && isOpen) {
      onClose();
    }
  };

  if (isOpen) {
    document.addEventListener('keydown', handleEscKey);
  }

  return () => {
    document.removeEventListener('keydown', handleEscKey);
  };
}, [isOpen, onClose]);
```

### 3. 視覺設計原則
- **拖動手柄**：使用 Modal 標題列作為拖動區域
- **游標提示**：`cursor: grab` 和 `cursor: grabbing`
- **視覺指示**：拖動把手圖標（點狀圖案）
- **互動回饋**：拖動時移除過渡動畫，放開後恢復

### 4. 互動細節
- **位置重置**：每次開啟 Modal 重置到中心位置
- **按鈕保護**：關閉按鈕使用 `stopPropagation` 防止觸發拖動
- **多種關閉方式**：ESC 鍵、關閉按鈕、點擊背景

## 影響

### 正面
- ✅ 提升使用者體驗，可以調整視窗位置以查看背後內容
- ✅ 符合桌面應用程式的操作習慣
- ✅ ESC 鍵提供快速關閉的便利性
- ✅ 實作簡單，不需要額外的函式庫

### 負面
- ⚠️ 觸控裝置需要額外處理（touch 事件）
- ⚠️ 需要防止拖動到視窗外
- ⚠️ 多個 Modal 同時開啟時需要處理 z-index

## 實作指引

### 完整的可拖動 Modal 模板：

```typescript
const DraggableModal: React.FC<ModalProps> = ({ isOpen, onClose, children }) => {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

  // 重置位置
  useEffect(() => {
    if (isOpen) {
      setPosition({ x: 0, y: 0 });
    }
  }, [isOpen]);

  // ESC 鍵關閉
  useEffect(() => {
    const handleEscKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscKey);
    }

    return () => {
      document.removeEventListener('keydown', handleEscKey);
    };
  }, [isOpen, onClose]);

  // 拖動邏輯
  const handleMouseDown = (e: React.MouseEvent) => {
    setIsDragging(true);
    setDragStart({
      x: e.clientX - position.x,
      y: e.clientY - position.y
    });
  };

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (isDragging) {
        setPosition({
          x: e.clientX - dragStart.x,
          y: e.clientY - dragStart.y
        });
      }
    };

    const handleMouseUp = () => {
      setIsDragging(false);
    };

    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, dragStart]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50">
      {/* 背景遮罩 */}
      <div 
        className="fixed inset-0 bg-black bg-opacity-50"
        onClick={onClose}
      />
      
      {/* Modal 本體 */}
      <div 
        className="relative bg-white rounded-lg shadow-xl"
        style={{
          transform: `translate(${position.x}px, ${position.y}px)`,
          transition: isDragging ? 'none' : 'transform 0.2s ease-out'
        }}
      >
        {/* 拖動手柄（標題列） */}
        <div 
          className="px-4 py-3 border-b cursor-grab active:cursor-grabbing"
          onMouseDown={handleMouseDown}
        >
          <h3>Modal 標題</h3>
          <button 
            onClick={onClose}
            onMouseDown={(e) => e.stopPropagation()}
          >
            關閉
          </button>
        </div>
        
        {/* 內容 */}
        <div className="p-4">
          {children}
        </div>
      </div>
    </div>
  );
};
```

## 注意事項

1. **效能優化**：使用 `transform` 而非 `top/left` 以獲得更好的效能
2. **邊界檢測**：考慮加入邊界檢測防止拖動到螢幕外
3. **觸控支援**：行動裝置需要額外處理 touch 事件
4. **無障礙性**：確保鍵盤導航仍然可用

## 參考資料
- 實作檔案：`/frontend/src/components/ViewPbiDetailModal.tsx`
- MDN: [Pointer Events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events)
- React 文檔：[合成事件](https://react.dev/reference/react-dom/components/common#react-event-object)

## 結論
這個模式提供了更靈活的 Modal 使用體驗，特別適合需要同時查看 Modal 和背景內容的場景。建議在所有詳情檢視、設定面板等非阻塞性 Modal 中採用此模式。