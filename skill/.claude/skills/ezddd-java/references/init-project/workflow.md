# Project Initialization Workflow

## Step 0: Load Project Configuration (MANDATORY)

### 0.1 Read project-config.json

```bash
READ: .dev/project-config.json
```

**Extract these values:**

```
${projectName}        = project-config.json → projectName
${rootPackage}        = project-config.json → rootPackage
${techStack}          = project-config.json → techStack
${dualProfileSupport} = project-config.json → architecture.commandDefaults.dualProfileSupport
${testDbPort}         = project-config.json → database.environments.test.port
${prodDbPort}         = project-config.json → database.environments.production.port
${dbName}             = project-config.json → database.name
${dbPassword}         = project-config.json → database.environments.test.password
```

### 0.2 Validate Configuration

```
╔════════════════════════════════════════════════════════════════╗
║  Configuration Validation                                       ║
╠════════════════════════════════════════════════════════════════╣
║  - [ ] rootPackage is defined (e.g., "tw.teddysoft.aiscrum")   ║
║  - [ ] projectName is defined (e.g., "ai-scrum")               ║
║  - [ ] techStack is "java-ezddd-spring"                        ║
║  - [ ] database.environments.test.port is defined              ║
╚════════════════════════════════════════════════════════════════╝
```

### 0.3 Calculate Paths

```
${rootPackagePath}   = ${rootPackage} with "." replaced by "/"
                      Example: "tw.teddysoft.aiscrum" → "tw/teddysoft/aiscrum"

${mainJavaPath}      = src/main/java/${rootPackagePath}
${testJavaPath}      = src/test/java/${rootPackagePath}
${mainResourcesPath} = src/main/resources
${testResourcesPath} = src/test/resources
```

### 0.4 Check Existing Files (unless --force)

```bash
find src/main/java -name "*App.java" -exec grep -l "@SpringBootApplication" {} \; | head -1
```

**If found and no --force flag:**
```
⚠️ Project appears to be already initialized.
   Use --force to reinitialize and overwrite existing files.
   Skipping initialization.
```

---

## Step 1: Generate Main Application (Phase 1)

### 1.1 Create Directory Structure

```bash
mkdir -p ${mainJavaPath}
mkdir -p ${mainJavaPath}/common/entity
mkdir -p ${mainJavaPath}/common/io/springboot/config
mkdir -p ${mainJavaPath}/common/io/springboot/config/connectionframe
mkdir -p ${mainResourcesPath}
mkdir -p ${testJavaPath}/test/base
mkdir -p ${testJavaPath}/test/suite/inmemory
mkdir -p ${testJavaPath}/test/suite/outbox
mkdir -p ${testResourcesPath}
```

### 1.2 Generate Main Application Class

**File:** `${mainJavaPath}/${AppName}App.java`

> See `templates.md` for complete code

---

## Step 2: Generate Shared Infrastructure (Phase 2)

Generate these files in `${mainJavaPath}/common/`:

| File | Location |
|------|----------|
| DateProvider.java | `common/entity/` |
| DomainEventMapperConfig.java | `common/io/springboot/config/` |
| SharedInfrastructureConfig.java | `common/io/springboot/config/` |
| SharedOutboxConfig.java | `common/io/springboot/config/` |
| VolatileRelayConfig.java | `common/io/springboot/config/connectionframe/` |
| CatchupRelayConfig.java | `common/io/springboot/config/connectionframe/` |

> **⚠️ Connection Frame configs 是必要的！** 缺少 VolatileRelayConfig 會導致 InMemory profile
> 找不到 `InMemoryMessageBroker` bean；缺少 CatchupRelayConfig 會導致 Outbox profile 啟動失敗。
> See `templates.md` for complete code

---

## Step 3: Generate Test Infrastructure (Phase 3)

Generate these files in `${testJavaPath}/`:

| File | Location |
|------|----------|
| BaseSpringBootTest.java | `test/base/` |
| BaseUseCaseTest.java | `test/base/` |
| NotifyFakeHandleAllEventsService.java | `common/` |

> **注意**：TestSuite（含 inner class ProfileSetter）在 UC 執行時產生，非 init-project 階段。
> See `templates.md` for complete code

---

## Step 4: Generate Application Properties (Phase 4)

Generate these files:

| File | Location |
|------|----------|
| application.properties | `src/main/resources/` |
| application-inmemory.properties | `src/main/resources/` |
| application-outbox.properties | `src/main/resources/` |
| application-test-inmemory.properties | `src/test/resources/` |
| application-test-outbox.properties | `src/test/resources/` |

> See `templates.md` for complete content

---

## Step 5: Verification & Report

### 5.1 Verify All Files Created

```bash
find src -name "*.java" -o -name "*.properties" | wc -l
```

### 5.2 Compile Check

```bash
mvn clean compile -q
```

### 5.3 Generate Report

```
╔════════════════════════════════════════════════════════════════╗
║                    INITIALIZATION REPORT                        ║
╠════════════════════════════════════════════════════════════════╣
║  Project: ${projectName}                                        ║
║  Root Package: ${rootPackage}                                   ║
║  Dual Profile Support: ${dualProfileSupport}                    ║
╠════════════════════════════════════════════════════════════════╣
║  Phase 1: Main Application                                      ║
║  ├── ${AppName}App.java                            ✅           ║
║                                                                ║
║  Phase 2: Shared Infrastructure                                ║
║  ├── DateProvider.java                             ✅           ║
║  ├── DomainEventMapperConfig.java                  ✅           ║
║  ├── SharedInfrastructureConfig.java               ✅           ║
║  ├── SharedOutboxConfig.java                       ✅           ║
║  ├── VolatileRelayConfig.java                      ✅           ║
║  └── CatchupRelayConfig.java                       ✅           ║
║                                                                ║
║  Phase 3: Test Infrastructure                                  ║
║  ├── BaseSpringBootTest.java                       ✅           ║
║  ├── BaseUseCaseTest.java                          ✅           ║
║  └── NotifyFakeHandleAllEventsService.java         ✅           ║
║  (TestSuite 在 UC 執行時產生，非 init-project 階段)            ║
║                                                                ║
║  Phase 4: Application Properties                               ║
║  ├── application.properties                        ✅           ║
║  ├── application-inmemory.properties               ✅           ║
║  ├── application-outbox.properties                 ✅           ║
║  ├── application-test-inmemory.properties          ✅           ║
║  └── application-test-outbox.properties            ✅           ║
╠════════════════════════════════════════════════════════════════╣
║  Compilation: ✅ SUCCESS                                        ║
╠════════════════════════════════════════════════════════════════╣
║  Next Steps:                                                   ║
║  1. Create your first Aggregate using /execute-uc              ║
║  2. Run tests: mvn test -Dtest=InMemoryTestSuite               ║
╚════════════════════════════════════════════════════════════════╝
```

---

## Failure Conditions

This execution is considered FAILED if:

1. **Step 0 failed** - project-config.json not found or invalid
2. **Step 1 failed** - Main Application not generated
3. **Step 2 failed** - Any shared infrastructure file not generated
4. **Step 3 failed** - Any test infrastructure file not generated
5. **Step 4 failed** - Any application properties file not generated
6. **Step 5 failed** - Compilation fails
