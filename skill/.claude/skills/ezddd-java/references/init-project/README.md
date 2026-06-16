# Project Initialization (ezddd-java)

## Overview

初始化新專案所需的基礎設施，支援：
- **Dual Profile** (InMemory + Outbox)
- **Event Sourcing** with Domain Events
- **Clean Architecture** compliant structure
- **Test Infrastructure** with ProfileSetter pattern

## File Structure

```
references/init-project/
├── README.md                  ← 本檔案
├── workflow.md                ← 執行流程
└── templates.md               ← 完整程式碼模板
```

## When to Use

| Scenario | Use This Skill |
|----------|---------------|
| Starting a new project from scratch | ✅ Yes |
| `src/` directory is empty or missing | ✅ Yes |
| Code executor reports missing infrastructure | ✅ Yes |
| Adding infrastructure to existing project | ✅ Yes (with --force) |
| Project already initialized | ❌ No (unless --force) |

## Execution Flow

```
Step 0: Load Project Configuration
   ↓
Step 1: Generate Main Application (Phase 1)
   ↓
Step 2: Generate Shared Infrastructure (Phase 2)
   ↓
Step 3: Generate Test Infrastructure (Phase 3)
   ↓
Step 4: Generate Application Properties (Phase 4)
   ↓
Step 5: Verification & Report
```

## Generated Files Summary

### Phase 1: Main Application
- `${AppName}App.java` - Spring Boot 主程式

### Phase 2: Shared Infrastructure (6 files)
- `DateProvider.java` - 統一時間管理
- `DomainEventMapperConfig.java` - Domain Event 自動註冊 (ADR-047)
- `SharedInfrastructureConfig.java` - InMemory profile 基礎設施
- `SharedOutboxConfig.java` - Outbox profile JPA 配置 (EntityManager + JpaRepositoryFactory)
- `VolatileRelayConfig.java` - MessageDb → Broker relay (Connection Frame)
- `CatchupRelayConfig.java` - Catchup relay (Connection Frame)

### Phase 3: Test Infrastructure (3 files)
- `BaseSpringBootTest.java` - Spring Boot 測試基底類別
- `BaseUseCaseTest.java` - UseCase 測試基底類別（含事件捕獲）
- `NotifyFakeHandleAllEventsService.java` - 事件捕獲服務

> **注意**：TestSuite（含 inner class ProfileSetter）在 UC 執行時產生，非 init-project 階段。

### Phase 4: Application Properties (5 files)
- `application.properties` - 主配置
- `application-inmemory.properties` - InMemory profile
- `application-outbox.properties` - Outbox profile
- `application-test-inmemory.properties` - 測試 InMemory profile
- `application-test-outbox.properties` - 測試 Outbox profile

## Configuration Source

從 `.dev/project-config.json` 讀取：

```
${projectName}        = projectName
${rootPackage}        = rootPackage
${techStack}          = techStack
${dualProfileSupport} = architecture.commandDefaults.dualProfileSupport
${testDbPort}         = database.environments.test.port
${prodDbPort}         = database.environments.production.port
${dbName}             = database.name
${dbPassword}         = database.environments.test.password
```

## Usage

```bash
/init-project                  # 使用 project-config.json 預設值
/init-project --dry-run        # 預覽產生的檔案
/init-project --force          # 強制覆蓋現有檔案
```

## Related Files

- `references/rules/testing-patterns.md` - 測試模式規範
- `references/templates/base-test-classes.md` - 測試基底類別模板
- `references/templates/test-suites.md` - 測試套件模板
