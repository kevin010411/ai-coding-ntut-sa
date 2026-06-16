# ADR-022: EzDDD Gateway 版本升級至 1.0.0

## Status
Accepted

## Date
2025-01-22

## Context
專案中使用 ezddd-gateway 作為事件存儲和事件處理的核心依賴。原本使用的是 0.0.3 版本，現在需要升級到 1.0.0 正式版本。

### 版本差異
- **0.0.3**: 早期開發版本，可能存在 API 不穩定性
- **1.0.0**: 正式發布版本，API 已穩定，向後相容性得到保證

### 影響範圍
此版本升級影響以下組件：
- Event Sourcing 實作
- Event Store Database Gateway (ez-esdb)
- Event Stream Gateway (ez-es)
- Outbox Pattern 實作 (ez-outbox)

## Decision
將 ezddd-gateway 從 0.0.3 版本升級至 1.0.0 版本。

### 更新清單
1. **pom.xml**: 更新 `<ezddd-gateway.version>` property
2. **.dev/project-config.json**: 更新 `ezdddGatewayVersion` 配置
3. **技術文檔**: 更新所有 .ai 目錄下的相關文檔
   - .ai/DEPENDENCY-TROUBLESHOOTING.md
   - .ai/tech-stacks/java-ezddd-spring/project-config-template.json
   - .ai/tech-stacks/java-ezddd-spring/examples/reference/maven-dependencies.md

## Consequences

### 正面影響
1. **穩定性提升**: 1.0.0 是正式版本，經過充分測試
2. **向後相容**: 主版本號為 1，保證 API 穩定性
3. **長期支援**: 正式版本通常有更好的維護和支援
4. **文檔完整**: 正式版本通常有更完整的文檔

### 負面影響
1. **潛在的破壞性變更**: 從 0.x 升級到 1.x 可能存在破壞性變更
2. **測試需求**: 需要完整測試所有使用 ezddd-gateway 的功能

### 風險緩解
1. 執行完整的測試套件確保功能正常
2. 檢查官方升級指南（如果有）
3. 保留回滾計劃，如果發現問題可以快速回退到 0.0.3

## Implementation Notes

### 驗證步驟
```bash
# 清理並重新編譯
mvn clean compile

# 執行所有測試
mvn test

# 特別關注 Event Sourcing 相關測試
mvn test -Dtest="*EventSourcing*Test"
```

### 配置同步
確保以下檔案的版本號保持一致：
- pom.xml (Maven 配置)
- .dev/project-config.json (專案配置)
- .ai/ 目錄下的所有技術文檔

## Related ADRs
- ADR-005: AI Task 執行 SOP
- ADR-013: Task Results Tracking

## References
- ezddd-gateway GitHub repository (如果公開)
- Maven Central: tw.teddysoft.ezddd-gateway