# ADR-031: Reactor 介面必須繼承 Reactor<DomainEventData>

## 狀態
Accepted (2025-08-19)
Updated (2025-12-25) - 新增目錄結構和命名規範

## 背景
在實作 Reactor 時發現，有些文檔和範例錯誤地顯示 Reactor 介面應該繼承 `Reactor<DomainEvent>`，但根據 ezddd 框架的設計，正確的方式應該是繼承 `Reactor<DomainEventData>`。

這個錯誤可能導致：
1. 型別不匹配的編譯錯誤
2. 無法正確處理 DomainEvent
3. 與 ezddd 框架不相容

## 決策
所有 Reactor 介面必須繼承 `Reactor<DomainEventData>`，而非 `Reactor<DomainEvent>` 或其他型別。

### 目錄結構
```
{aggregate}/usecase/
├── port/in/reactor/                          # Reactor 介面
│   └── When{Event}{Reaction}Reactor.java
└── service/reactor/                          # Reactor 實作
    └── {Reaction}When{Event}Service.java
```

### 命名規範
| 類型 | 命名格式 | 範例 |
|-----|---------|------|
| Interface | `When{Event}{Reaction}Reactor` | `WhenBoardDeletedCleanupOrphanWorkflowsReactor` |
| Service | `{Reaction}When{Event}Service` | `CleanupOrphanWorkflowsWhenBoardDeletedService` |
| Test | `{Reaction}When{Event}ServiceTest` | `CleanupOrphanWorkflowsWhenBoardDeletedServiceTest` |

### 正確寫法
```java
// 位置: usecase/port/in/reactor/WhenSprintStartedNotifyProductBacklogItemReactor.java
import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

public interface WhenSprintStartedNotifyProductBacklogItemReactor extends Reactor<DomainEventData> {
}
```

### 錯誤寫法
```java
// ❌ 錯誤：使用 DomainEvent
public interface WhenSprintStartedNotifyPbiReactor extends Reactor<DomainEvent> {
}

// ❌ 錯誤：沒有泛型參數
public interface WhenSprintStartedNotifyPbiReactor extends Reactor {
}

// ❌ 錯誤：舊命名格式
public interface NotifyProductBacklogItemWhenSprintStartedReactor extends Reactor<DomainEventData> {
}
```

## 理由

### 1. 框架相容性
ezddd 框架的 MessageBus 發布的是 `DomainEventData` 型別，Reactor 必須能夠接收這個型別才能正確整合。

### 2. 型別安全
使用正確的泛型參數可以在編譯時期就發現型別錯誤，避免執行時期的問題。

### 3. 一致性
所有的 Domain Event Data 都實作 `DomainEventData` 介面，Reactor 使用相同的介面保持一致性。

## 實作要點

### Reactor Interface
```java
// 位置: pbi/usecase/port/in/reactor/WhenSprintStartedNotifyProductBacklogItemReactor.java
package tw.teddysoft.aiscrum.pbi.usecase.port.in.reactor;

import tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor;

/**
 * Reactor that listens to SprintStarted events and automatically updates
 * all ProductBacklogItems in that Sprint to IN_PROGRESS state.
 */
public interface WhenSprintStartedNotifyProductBacklogItemReactor extends Reactor<DomainEventData> {
}
```

### Service Implementation
```java
// 位置: pbi/usecase/service/reactor/NotifyProductBacklogItemWhenSprintStartedService.java
package tw.teddysoft.aiscrum.pbi.usecase.service.reactor;

public class NotifyProductBacklogItemWhenSprintStartedService
        implements WhenSprintStartedNotifyProductBacklogItemReactor {

    @Override
    public void execute(DomainEventData message) {
        if (message == null) {
            return;
        }

        // 使用 DomainEventMapper 將 DomainEventData 轉換為 InternalDomainEvent
        InternalDomainEvent domainEvent = DomainEventMapper.toDomain(message);

        if (domainEvent instanceof SprintEvents.SprintStarted sprintStarted) {
            whenSprintStarted(sprintStarted);
        }
        // 忽略其他事件類型
    }

    private void whenSprintStarted(SprintEvents.SprintStarted sprintStarted) {
        // 處理事件邏輯
    }
}
```

### Spring Configuration
```java
@Bean
public WhenSprintStartedNotifyProductBacklogItemReactor whenSprintStartedNotifyPbiReactor(
        FindPbisBySprintIdInquiry inquiry,
        Repository<ProductBacklogItem, ProductBacklogItemId> repository) {

    return new NotifyProductBacklogItemWhenSprintStartedService(inquiry, repository);
}
```

## 影響

### 需要更新的文件
1. `.ai/tech-stacks/java-ezddd-spring/coding-standards.md` - ✅ 已更新
2. `.ai/tech-stacks/java-ezddd-spring/examples/generation-templates/reactor-full.md` - ✅ 已更新
3. `.ai/tech-stacks/java-ezddd-spring/prompts/reactor-code-review-prompt.md` - ✅ 已更新
4. `.ai/tech-stacks/java-ezddd-spring/examples/inquiry-archive/README.md` - ✅ 已更新

### 檢查點
在 Code Review 時必須檢查：
- [ ] Reactor 介面位於 `usecase/port/in/reactor/` 目錄
- [ ] Reactor 介面命名格式：`When{Event}{Reaction}Reactor`
- [ ] Reactor 介面繼承 `Reactor<DomainEventData>`
- [ ] Service 位於 `usecase/service/reactor/` 目錄
- [ ] Service 命名格式：`{Reaction}When{Event}Service`
- [ ] Service 實作 `execute(DomainEventData message)` 方法
- [ ] 使用 `DomainEventMapper.toDomain(message)` 進行轉換
- [ ] 正確的 import statements

## 決策日期
2025-08-19

## 參與者
- AI Assistant (Claude)
- User

## 參考資料
- ezddd framework documentation
- `tw.teddysoft.ezddd.usecase.port.in.interactor.Reactor`
- `tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventData`
- `tw.teddysoft.ezddd.usecase.port.inout.domainevent.DomainEventMapper`