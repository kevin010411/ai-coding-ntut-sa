初始化新專案的基礎設施（只需執行一次）。

**包含 ADR-047 共用基礎設施配置**：自動產生 `DomainEventMapperConfig.java` 等共用配置，
Sub-agent 不需修改這些檔案，新增 Aggregate 只需建立 `*Events.java` 並定義 `static mapper()` 方法。

## 檢查並產生共用元件

### Step 1: 檢查 Spring Boot 主類別

檢查是否存在 `@SpringBootApplication` 類別：
```bash
find src/main/java -name "*.java" -exec grep -l "@SpringBootApplication" {} \;
```

如不存在，依據 `.ai/tech-stacks/java-ezddd-spring/prompts/shared/spring-boot-conventions.md` 產生：
- `src/main/java/tw/teddysoft/aiscrum/AiScrumApp.java`

### Step 2: 檢查 DateProvider

檢查是否存在 `DateProvider.java`：
```bash
find src/main/java -name "DateProvider.java"
```

如不存在，依據 `.ai/tech-stacks/java-ezddd-spring/examples/generation-templates/local-utils.md` 產生：
- `src/main/java/tw/teddysoft/aiscrum/common/entity/DateProvider.java`

### Step 3: 檢查 MessageDb Config

檢查是否存在 `InMemoryMessageDbConfig.java`：
```bash
find src/main/java -name "InMemoryMessageDbConfig.java"
```

如不存在，執行 `/generate-cf2-config` 產生：
- `InMemoryMessageDbConfig.java`
- `MessageDbConfig.java`
- `VolatileRelayConfig.java`
- `CatchupRelayConfig.java`

### Step 4: 檢查 application.properties

檢查是否存在基本配置檔案：
- `src/main/resources/application.properties`
- `src/main/resources/application-inmemory.properties`
- `src/test/resources/application-test-inmemory.properties`

如不存在，依據 `.ai/tech-stacks/java-ezddd-spring/prompts/shared/fresh-project-init.md` 產生。

### Step 5: 檢查共用基礎設施配置（ADR-047）🆕

檢查是否存在 `DomainEventMapperConfig.java`：
```bash
find src/main/java -name "DomainEventMapperConfig.java"
```

如不存在，依據 `.claude/skills/ezddd-java/references/init-project/workflow.md` 產生：
- `src/main/java/[rootPackage]/common/io/springboot/config/DomainEventMapperConfig.java`
- `src/main/java/[rootPackage]/common/io/springboot/config/SharedInfrastructureConfig.java`
- `src/main/java/[rootPackage]/common/io/springboot/config/SharedOutboxConfig.java`

**⚠️ ADR-047 重要原則**：
- `DomainEventMapperConfig` 使用 Spring ClassPath Scanning 自動發現所有 `*Events` 類別
- Sub-agent **不需修改**這些檔案
- 新增 Aggregate 只需建立 `*Events.java` 並定義 `static mapper()` 方法

### Step 6: 創建 connectionframe 目錄

確保目錄存在：
```bash
mkdir -p src/main/java/[rootPackage]/common/io/springboot/config/connectionframe
```

**此目錄用於 CF2 配置**：
- `VolatileRelayConfig.java` - MessageDb → Broker relay
- `CatchupRelayConfig.java` - Catchup relay

**⚠️ 注意：ReactorConfig (CF3) 是 Aggregate-Specific！**
```
❌ 不再使用共用的 ConsumerToReactorConfig.java
✅ ReactorConfig 由 RIF sub-agent 在目標 Aggregate 的 config 目錄建立：
   - product/io/springboot/config/ProductReactorConfig.java
   - sprint/io/springboot/config/SprintReactorConfig.java
```

## 輸出報告

```
專案初始化檢查報告：

[✓] AiScrumApp.java - 已存在
[✓] DateProvider.java - 已存在
[!] InMemoryMessageDbConfig.java - 已產生
[!] application.properties - 已產生
[✓] DomainEventMapperConfig.java - 已存在 (ADR-047)
[✓] SharedInfrastructureConfig.java - 已存在
[✓] SharedOutboxConfig.java - 已存在
[✓] connectionframe/ 目錄 - 已存在

專案已準備好，可以開始實作 Use Cases。
```

## 使用時機

**新專案第一步**：
```
/init-project
```

**之後執行各 Use Cases**：
```
/execute-uc .dev/specs/product/usecase/create-product.json
/execute-uc .dev/specs/sprint/usecase/create-sprint.json
...
```
