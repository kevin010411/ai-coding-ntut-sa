# ADR-046: ezapp-starter 版本升級至 2.0.0

## Status
Accepted

## Date
2025-11-27

## Context
專案中使用 ezapp-starter 作為整合框架，包含 EZDDD、CQRS、Event Sourcing、uContract、ezSpec 等核心功能。原本使用的是 1.0.0 版本，現在需要升級到 2.0.0 版本。

### 版本差異
- **1.0.0**: 初始穩定版本
- **2.0.0**: 主版本升級，可能包含新功能或 API 調整

### 影響範圍
此版本升級影響以下組件：
- ezddd-core (DDD 核心框架)
- ezcqrs (CQRS 支援)
- ezddd-gateway (Outbox Pattern, Event Sourcing)
- uContract (Design by Contract)
- ezSpec (BDD 測試框架)

## Decision
將 ezapp-starter 從 1.0.0 版本升級至 2.0.0 版本。

### 更新清單
1. **配置檔案**:
   - `.dev/project-config.json` - 更新 `ezappStarterVersion` 為 2.0.0
   - `.dev/project-config-outbox.json` - 更新 `ezappStarterVersion` 為 2.0.0
   - `.ai/tech-stacks/java-ezddd-spring/project-config-template.json` - 更新模板版本號
   - `.ai/tech-stacks/java-ezddd-spring/examples/.versions.json` - 更新版本追蹤

2. **技術文檔**:
   - `.ai/tech-stacks/java-ezddd-spring/guides/EZAPP-STARTER-API-REFERENCE.md` - 更新 API 參考中的版本號
   - `.ai/tech-stacks/java-ezddd-spring/guides/VERSION-PLACEHOLDER-GUIDE.md` - 更新佔位符說明
   - `.ai/tech-stacks/java-ezddd-spring/EZDDD-FRAMEWORK-REFERENCE.md` - 更新框架參考
   - `.ai/tech-stacks/java-ezddd-spring/examples/reference/maven-dependencies.md` - 更新 Maven 依賴範例

## Consequences

### 正面影響
1. **功能更新**: 使用最新版本的框架功能
2. **Bug 修復**: 受益於 2.0.0 版本的錯誤修復
3. **效能提升**: 可能包含效能優化
4. **生態系統同步**: 與其他使用 2.0.0 的專案保持一致

### 負面影響
1. **潛在的破壞性變更**: 主版本號變更 (1.x → 2.x) 可能包含不相容的 API 變更
2. **學習成本**: 團隊可能需要學習新的 API 或模式

### 風險緩解
1. ✅ 執行完整的編譯測試確保無編譯錯誤
2. ✅ 執行完整的測試套件確保功能正常
3. 保留回滾計劃，如果發現問題可以快速回退到 1.0.0

## Implementation Notes

### 驗證步驟
```bash
# 清理並重新編譯
mvn clean compile

# 執行所有測試 (使用 inmemory profile)
SPRING_PROFILES_ACTIVE=test-inmemory mvn test
```

### 驗證結果
- ✅ 編譯成功：`mvn clean compile` 無錯誤
- ✅ 測試通過：所有測試案例通過

### 配置同步確認
以下檔案已更新為 2.0.0：
- [x] `.dev/project-config.json`
- [x] `.dev/project-config-outbox.json`
- [x] `.ai/tech-stacks/java-ezddd-spring/project-config-template.json`
- [x] `.ai/tech-stacks/java-ezddd-spring/examples/.versions.json`
- [x] `.ai/tech-stacks/java-ezddd-spring/guides/EZAPP-STARTER-API-REFERENCE.md`
- [x] `.ai/tech-stacks/java-ezddd-spring/guides/VERSION-PLACEHOLDER-GUIDE.md`
- [x] `.ai/tech-stacks/java-ezddd-spring/EZDDD-FRAMEWORK-REFERENCE.md`
- [x] `.ai/tech-stacks/java-ezddd-spring/examples/reference/maven-dependencies.md`

## Related ADRs
- ADR-022: EzDDD Gateway 版本升級至 1.0.0

## References
- ezapp-starter: tw.teddysoft.ezapp:ezapp-starter
- Maven Central 依賴管理
