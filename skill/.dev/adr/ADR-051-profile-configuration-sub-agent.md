# ADR-051: Profile Configuration Sub-agent

## 狀態
已實施 (Implemented)

## 日期
2025-09-05

## 背景 (Context)

在專案開發過程中，Spring Profile 配置錯誤是導致應用程式無法啟動的主要原因之一：

1. **Repository Bean Not Found**：不同 Profile 需要不同的 Repository 實作，配置不當會導致 Bean 缺失
2. **DataSource Configuration Failed**：InMemory profile 不需要資料庫，但 Spring Boot 自動配置仍會嘗試創建 DataSource
3. **Profile Configuration Conflicts**：JPA 在 InMemory 模式下仍嘗試初始化，導致啟動失敗

這些問題在每個新專案開始時都會重複出現，需要標準化的解決方案。

## 決策 (Decision)

創建專門的 Profile Configuration Sub-agent 來處理 Spring Profile 配置：

1. **專責化**：Sub-agent 專注於 Profile 配置，不處理其他業務邏輯
2. **標準化**：提供標準的配置模板和最佳實踐
3. **自動化**：自動生成所有必要的配置檔案和類別
4. **防護性**：預防常見的配置錯誤

## 實作細節

### Sub-agent 架構
- **位置**: `.ai/tech-stacks/java-ezddd-spring/prompts/profile-config-sub-agent-prompt.md`
- **分類**: Infrastructure Sub-agents
- **編號**: 14 (在 Sub-agent 系統中)

### 核心功能
1. **Properties 檔案生成**
   - application.properties (主配置)
   - application-inmemory.properties (含 DataSource 排除)
   - application-outbox.properties (含資料庫配置)
   - 測試環境配置檔案

2. **Configuration 類別生成**
   - CommonConfiguration (共用配置)
   - InMemoryConfiguration (InMemory 專用)
   - OutboxConfiguration (Outbox 專用)
   - 使用 @Profile 和 @ConditionalOn 註解隔離

3. **驗證機制**
   - 檢查 DataSource 排除配置
   - 驗證 Bean 定義完整性
   - Profile 隔離檢查

### 使用方式
```
請使用 profile-config-sub-agent workflow 配置 Spring Profiles
```

## 效益 (Consequences)

### 正面效益
- ✅ **減少錯誤率**：標準化配置減少人為錯誤
- ✅ **加快開發速度**：不需要手動創建大量配置檔案
- ✅ **提高一致性**：所有專案使用相同的配置模式
- ✅ **知識傳承**：新手也能正確配置 Profile
- ✅ **防護機制**：自動包含必要的排除配置

### 潛在挑戰
- ⚠️ **學習曲線**：需要了解 sub-agent 系統的使用方式
- ⚠️ **客製化需求**：特殊情況可能需要手動調整生成的配置
- ⚠️ **維護負擔**：Sub-agent prompt 需要隨框架更新而維護

## 相關文件

### Sub-agent 系統
- [SUB-AGENT-SYSTEM.md](.ai/tech-stacks/java-ezddd-spring/SUB-AGENT-SYSTEM.md) - Sub-agent 架構說明
- [profile-config-sub-agent-prompt.md](.ai/tech-stacks/java-ezddd-spring/prompts/profile-config-sub-agent-prompt.md) - Sub-agent 實作

### 配置指南
- [PREVENT-REPOSITORY-BEAN-MISSING.md](.ai/tech-stacks/java-ezddd-spring/guides/PREVENT-REPOSITORY-BEAN-MISSING.md)
- [PROFILE-CONFIGURATION-COMPLEXITY-SOLUTION.md](.ai/tech-stacks/java-ezddd-spring/guides/PROFILE-CONFIGURATION-COMPLEXITY-SOLUTION.md)
- [SPRING-PROFILE-STRATEGY.md](.ai/tech-stacks/java-ezddd-spring/guides/SPRING-PROFILE-STRATEGY.md)

### 模板資源
- [application-properties-templates.md](.ai/tech-stacks/java-ezddd-spring/templates/application-properties-templates.md)
- [profile-isolated-configurations.md](.ai/tech-stacks/java-ezddd-spring/templates/profile-isolated-configurations.md)

## 成功指標

1. **應用啟動成功率**：使用 sub-agent 後，Spring Boot 啟動成功率應達 95% 以上
2. **配置時間縮短**：Profile 配置時間從 2-3 小時縮短至 10 分鐘
3. **錯誤減少**：Bean Not Found 和 DataSource 錯誤減少 90%

## 修訂歷史
- 2025-09-05：初始版本，建立 Profile Configuration Sub-agent