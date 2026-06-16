# ADR-021: Aggregate 欄位初始化模式

## 狀態
已接受

## 背景
在實作 ScrumTeam aggregate 時發現一個嚴重的 bug：團隊成員無法累積，每次新增成員都會覆蓋之前的成員。經過深入調查，發現是因為集合欄位的初始化時機不正確。

## 問題描述

### 錯誤的實作方式
```java
public class ScrumTeam extends AggregateRoot<ScrumTeamEvents> {
    private final List<TeamMember> members;
    
    // 錯誤：在 super() 之後初始化
    public ScrumTeam(List<ScrumTeamEvents> domainEvents) {
        super(domainEvents);  // 這裡會重播所有事件
        this.members = new ArrayList<>();  // 這會清空剛重播的成員！
    }
}
```

### 問題分析
1. `super(domainEvents)` 會呼叫父類別的建構子，觸發事件重播機制
2. 事件重播會呼叫 `when()` 方法，處理 `TeamMemberAdded` 等事件
3. 但是 `this.members = new ArrayList<>()` 在 super() **之後**執行
4. 導致事件重播時加入的成員全部被清空

## 決策

### 正確的實作方式
```java
public class ScrumTeam extends AggregateRoot<ScrumTeamEvents> {
    // 正確：在欄位宣告時初始化
    private final List<TeamMember> members = new ArrayList<>();
    
    public ScrumTeam(List<ScrumTeamEvents> domainEvents) {
        super(domainEvents);  // 事件重播時 members 已經初始化
        // members 已經在欄位宣告時初始化，不需要再初始化
    }
}
```

## 規則

### 1. 集合欄位必須在宣告時初始化
- ✅ `private final List<Member> members = new ArrayList<>();`
- ❌ `private final List<Member> members;` 然後在建構子中初始化

### 2. 建構子中的初始化順序
1. 欄位宣告時的初始化（最早執行）
2. super() 呼叫（觸發事件重播）
3. 建構子內的其他邏輯

### 3. Mapper 的 toDomain 實作
當從資料庫狀態重建 aggregate 時，必須恢復所有狀態：

```java
public static ScrumTeam toDomain(ScrumTeamData data) {
    // 有事件時從事件重建
    if (data.getDomainEventDatas() != null && !data.getDomainEventDatas().isEmpty()) {
        // 從事件重建
        var domainEvents = /* 轉換事件 */;
        return new ScrumTeam(domainEvents);
    } else {
        // 無事件時從當前狀態重建
        ScrumTeam scrumTeam = new ScrumTeam(/* 基本參數 */);
        
        // 重要：必須恢復集合欄位的狀態
        if (data.getMembers() != null) {
            for (TeamMemberData memberData : data.getMembers()) {
                scrumTeam.addMember(/* 參數 */);
            }
        }
        
        return scrumTeam;
    }
}
```

## 影響範圍
- 所有包含集合欄位的 Aggregate
- 所有 Mapper 的 toDomain 實作
- Event Sourcing 和 Outbox Pattern 的實作

## 檢查清單
- [ ] 所有集合欄位都在宣告時初始化
- [ ] 建構子中沒有在 super() 之後重新初始化集合
- [ ] Mapper.toDomain() 正確恢復所有狀態
- [ ] 測試驗證集合欄位可以正確累積元素

## 相關文件
- `.ai/tech-stacks/java-ezddd-spring/coding-standards/aggregate-standards.md`
- `.ai/tech-stacks/java-ezddd-spring/coding-standards/mapper-standards.md`
- `.ai/tech-stacks/java-ezddd-spring/CODE-REVIEW-CHECKLIST.md#event-sourcing-合規性檢查`

## 錯誤案例紀錄
- **日期**: 2025-08-24
- **問題**: ScrumTeam 的團隊成員無法累積
- **根因**: members 在 super() 之後初始化，清空了事件重播的結果
- **修正**: 將 members 初始化移到欄位宣告時
- **影響**: Backend Warriors 團隊每次只能保留最後一個成員