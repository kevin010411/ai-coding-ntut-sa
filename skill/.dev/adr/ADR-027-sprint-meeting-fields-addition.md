# ADR-010: Sprint Aggregate 新增三個 SprintMeeting 欄位

## 日期
2025-08-16

## 狀態
已接受 (Accepted)

## 背景 (Context)
Sprint aggregate 原本缺少 Scrum 框架中重要的三個會議資訊：
- Daily Scrum (每日站立會議)
- Sprint Review (Sprint 審查會議)
- Sprint Retrospective (Sprint 回顧會議)

這些會議是 Scrum 實踐中的關鍵活動，需要在系統中記錄其排程資訊。

## 決策 (Decision)
在 Sprint aggregate 中新增三個 SprintMeeting 類型的欄位：
```java
private SprintMeeting dailyScrum;
private SprintMeeting review;
private SprintMeeting retrospective;
```

### SprintMeeting Value Object 結構：
```java
public record SprintMeeting(
    Instant scheduledAt,  // 會議排程時間 (必填)
    String venue,         // 會議地點 (選填)
    Duration duration     // 會議持續時間 (選填)
)
```
**重要**: 只有 `scheduledAt` 是必填欄位，`venue` 和 `duration` 都是選填的

### 設計原則：
1. **三個欄位都可以為 null** - Sprint 創建時不一定已經排定所有會議
2. **使用 Value Object 模式** - SprintMeeting 是不可變的值物件
3. **向後相容** - 既有的 Sprint 可以正常運作，新欄位預設為 null

## 影響範圍 (Consequences)

### 正面影響：
1. **完整性** - Sprint 資訊更完整，涵蓋 Scrum 框架的所有重要會議
2. **擴展性** - 未來可以基於會議資訊開發更多功能（如會議提醒、衝突檢查等）
3. **領域正確性** - 更貼近 Scrum 實際運作模式

### 負面影響：
1. **複雜度增加** - Sprint 建構子參數從 10 個增加到 13 個
2. **測試需要更新** - 所有使用 Sprint 建構子的測試都需要修改
3. **API 變更** - CreateSprintController 需要處理新的輸入欄位

## 實作細節

### 修改的檔案：
1. **Domain Layer**
   - `Sprint.java` - 新增三個 SprintMeeting 欄位和對應的 getter
   - `SprintEvents.java` - SprintCreated event 新增三個欄位
   - `SprintMeeting.java` - 已存在的 Value Object

2. **Use Case Layer**
   - `CreateSprintUseCase.java` - 新增 SprintMeetingInput 內部類別
   - `CreateSprintService.java` - 處理 SprintMeeting 轉換邏輯

3. **Adapter Layer**
   - `CreateSprintController.java` - 新增 SprintMeetingDto 內部類別
   - 處理 REST API 請求中的會議資訊

4. **Specification**
   - `.dev/specs/sprint/usecase/create-sprint.json` - 更新規格檔案

### API 請求範例：
```json
{
  "name": "Sprint 1",
  "goal": "Complete user authentication",
  "startDateTime": "2025-02-01T09:00:00",
  "endDateTime": "2025-02-14T17:00:00",
  "zoneId": "Asia/Taipei",
  "state": "PLANNED",
  "capacity": 240,
  "dailyScrum": {
    "scheduledAt": "2025-02-02T09:30:00",
    "venue": "Team Room A",
    "duration": "PT15M"
  },
  "review": {
    "scheduledAt": "2025-02-14T14:00:00",
    "venue": "Conference Room B",
    "duration": "PT2H"
  },
  "retrospective": {
    "scheduledAt": "2025-02-14T16:00:00",
    "venue": "Conference Room B",
    "duration": "PT1H"
  }
}
```

## 替代方案 (Alternatives Considered)

### 方案 1：使用單一 meetings Map
```java
private Map<MeetingType, SprintMeeting> meetings;
```
- 優點：更靈活，可以輕易新增其他類型的會議
- 缺點：失去編譯時期的類型安全，需要額外的驗證邏輯

### 方案 2：創建獨立的 SprintMeetings Aggregate
- 優點：關注點分離，Sprint 保持簡單
- 缺點：增加系統複雜度，需要管理跨 Aggregate 的一致性

### 方案 3：使用事件記錄會議排程
```java
SprintEvents.DailyScrumScheduled
SprintEvents.ReviewScheduled
SprintEvents.RetrospectiveScheduled
```
- 優點：保留完整的變更歷史
- 缺點：查詢當前狀態較複雜

## 決策理由
選擇直接在 Sprint aggregate 中新增三個欄位是因為：
1. **簡單直接** - 實作簡單，易於理解
2. **符合領域模型** - 這些會議是 Sprint 的固有部分
3. **查詢效率** - 不需要額外的查詢或聚合
4. **向後相容** - 對既有系統影響最小

## 參考資料
- Scrum Guide 2020
- Domain-Driven Design by Eric Evans
- Clean Architecture by Robert C. Martin