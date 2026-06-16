# ADR-021: Scrum Role Mutual Exclusion Rules

## Status
Accepted

## Context
在 Scrum 團隊管理功能中，我們需要為團隊成員分配角色。根據 Scrum 框架的定義，有四種主要角色：
- Product Owner (PO)
- Scrum Master (SM)
- Developer
- Stakeholder

這些角色有不同的職責和參與程度，我們需要定義清楚的規則來管理角色分配。

## Decision
我們決定實施以下角色互斥規則：

### 1. Stakeholder 獨立性
- **Stakeholder 不能兼任其他角色**：Stakeholder 是外部利害關係人，不是 Scrum Team 的成員
- 選擇 Stakeholder 角色時，自動移除其他所有角色
- 已是 Stakeholder 時，無法選擇其他角色

### 2. 開發團隊角色可多選
- **PO、SM、Developer 可以多選**：這三個角色都是 Scrum Team 的成員
- 實務上，一個人可能同時擔任多個角色（例如：SM 兼 Developer）
- 這提供了小團隊的彈性配置

### 3. 實作細節
```typescript
// 角色選擇邏輯
if (role === 'STAKEHOLDER') {
  // 選擇 Stakeholder，清除所有其他角色
  setRoles(['STAKEHOLDER']);
} else {
  // 選擇其他角色，移除 Stakeholder
  const filteredRoles = currentRoles.filter(r => r !== 'STAKEHOLDER');
  setRoles([...filteredRoles, role]);
}
```

### 4. UI/UX 設計
- 視覺提示：顯示文字說明當前的選擇規則
- 禁用狀態：不可選的角色顯示為灰色
- 即時反饋：選擇 Stakeholder 時立即清除其他角色

## Consequences

### Positive
- **清晰的業務規則**：符合 Scrum 框架的角色定義
- **防止錯誤配置**：避免 Stakeholder 同時擔任開發團隊角色的邏輯錯誤
- **靈活性**：允許開發團隊成員身兼多職，適合小團隊
- **使用者友好**：清楚的視覺提示和即時反饋

### Negative
- **額外的驗證邏輯**：前後端都需要實作互斥規則
- **未來擴展限制**：如果業務規則改變，需要修改多處程式碼

## Alternatives Considered

### Alternative 1: 單一角色制
每個成員只能有一個角色。
- ✅ 簡單明瞭
- ❌ 不符合實際需求（例如 SM 兼 Developer 很常見）

### Alternative 2: 完全開放
所有角色都可以任意組合。
- ✅ 最大彈性
- ❌ 允許不合理的配置（Stakeholder 兼 PO）

### Alternative 3: 角色群組
將角色分為「內部」和「外部」兩組，組內可多選，組間互斥。
- ✅ 概念清晰
- ❌ 增加複雜度，但效果與現有方案相同

## Implementation Notes

### Frontend (React/TypeScript)
```typescript
interface UserWithRoles {
  userId: string;
  roles: string[];
}

const SCRUM_ROLES = [
  { value: 'PO', label: 'Product Owner' },
  { value: 'SM', label: 'Scrum Master' },
  { value: 'DEVELOPER', label: 'Developer' },
  { value: 'STAKEHOLDER', label: 'Stakeholder' },
];
```

### Backend (Java/Spring Boot)
```java
public enum ScrumRole {
    PO,          // Product Owner
    SM,          // Scrum Master
    DEVELOPER,   // Developer
    STAKEHOLDER  // Stakeholder
}

// TeamMember Value Object 支援多角色
public class TeamMember {
    private final String userId;
    private final Set<ScrumRole> roles;
    
    // 業務規則驗證
    public boolean isValidRoleCombination() {
        if (roles.contains(ScrumRole.STAKEHOLDER)) {
            return roles.size() == 1;
        }
        return true;
    }
}
```

## References
- [Scrum Guide](https://scrumguides.org/) - Official Scrum Framework definition
- [TeamMember Value Object Implementation](../../src/main/java/tw/teddysoft/aiscrum/scrumteam/entity/TeamMember.java)
- [Frontend Role Selection Component](../../frontend/src/components/AddTeamMemberModal.tsx)

## Decision Date
2025-08-20

## Decision Makers
- Development Team
- Product Owner

## Review Date
2025-09-20 (After first sprint using this feature)