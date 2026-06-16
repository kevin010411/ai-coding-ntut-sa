# 🚨 關鍵教訓 - 絕對不能再犯的錯誤

## 📅 2024-08-17: RTK Query 快取問題 - 反覆出現的嚴重錯誤

### 🔴 錯誤模式（已犯多次）
1. **補丁式解決** - 使用 `setTimeout`, `refetch()`, `keepUnusedDataFor: 0`
2. **重複覆蓋狀態** - 本地 state 和 RTK Query 快取互相干擾
3. **錯誤的欄位名稱** - 後端用 `status`，前端用 `state`，導致樂觀更新失效
4. **過度使用 useEffect** - 在每次資料更新時重設狀態

### ✅ 正確的解決方案

#### 1. RTK Query 樂觀更新必須精確
```javascript
// ❌ 錯誤：假設欄位名稱
if ('state' in task) {
  task.state = newState;
}

// ✅ 正確：明確更新後端使用的欄位
(task as any).status = newState; // 後端欄位
```

#### 2. 使用衍生狀態，不要儲存
```javascript
// ❌ 錯誤：儲存轉換後的資料
const [pbis, setPbis] = useState([]);
useEffect(() => {
  setPbis(transformData(pbiData));
}, [pbiData]); // 每次更新都覆蓋！

// ✅ 正確：使用 useMemo 衍生
const pbis = useMemo(() => {
  return transformData(pbiData);
}, [pbiData, expandedPbis]);
```

#### 3. 避免過度重設狀態
```javascript
// ❌ 錯誤：每次資料更新都重設
useEffect(() => {
  if (pbiData) {
    setExpandedPbis(new Set(pbiData.map(p => p.id)));
  }
}, [pbiData]);

// ✅ 正確：只在初始載入時設定
useEffect(() => {
  if (pbiData && expandedPbis.size === 0) {
    setExpandedPbis(new Set(pbiData.map(p => p.id)));
  }
}, [pbiData, expandedPbis.size]);
```

#### 4. 不要過度 invalidate
```javascript
// ❌ 錯誤：立即 invalidate 會覆蓋樂觀更新
invalidatesTags: [
  { type: 'Sprint', id: sprintId },
  { type: 'PBI', id: pbiId },
  { type: 'Task', id: taskId },
]

// ✅ 正確：成功時信任樂觀更新
invalidatesTags: (result, error) => {
  if (error) {
    return [{ type: 'Sprint' }]; // 只在錯誤時重新獲取
  }
  return []; // 成功時不要 invalidate
}
```

### 🎯 核心原則
1. **了解後端 API 的確切欄位名稱**
2. **使用衍生狀態而非儲存狀態**
3. **RTK Query 樂觀更新要精確**
4. **避免 useEffect 連鎖反應**
5. **不要用補丁，要從根本解決**

### 🔥 警告標記
當看到以下情況時，立即停下來重新思考：
- 使用 `setTimeout` 延遲處理
- 手動調用 `refetch()`
- 設定 `keepUnusedDataFor: 0`
- 在 useEffect 中設定從 props/query 衍生的 state
- 任務/資料「彈回」原位

### 📝 檢查清單
- [ ] 確認後端 API 的確切欄位名稱
- [ ] 使用 `useMemo` 而非 `useState` 來轉換資料
- [ ] 樂觀更新直接修改正確的欄位
- [ ] 避免在資料更新時重設 UI 狀態
- [ ] 測試：移動後離開頁面再回來是否正確

---

## 為什麼這個錯誤一再發生？

1. **沒有徹底理解資料流** - RTK Query → Component → UI
2. **急於解決表面問題** - 看到彈回就加 setTimeout
3. **沒有檢查實際的資料結構** - 假設欄位名稱而非確認
4. **複製貼上思維** - 從其他地方複製類似的程式碼

## 承諾

**我承諾**：
- 不再使用補丁式解決方案
- 徹底理解資料流才開始修改
- 確認 API 欄位名稱而非假設
- 使用正確的 React 模式（衍生狀態）
- 測試完整的使用流程，不只是當下的操作