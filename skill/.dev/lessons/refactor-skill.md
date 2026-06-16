# Problem Frame Execution 失敗經驗分析

## 任務資訊
- **日期**: 2026-01-28
- **Problem Frame**: CreateBoard (CBF)
- **Aggregate**: Board
- **執行結果**: 最終成功，但過程中遇到多個問題需要修復

---

## 問題 1: Bean 定義衝突

### 症狀
```
BeanDefinitionOverrideException: Cannot register bean definition for bean 'inMemoryProducer'
since there is already [Root bean... factoryBeanName=sharedInfrastructureConfig] bound.
```

### 根本原因
`SharedInfrastructureConfig` 和 `VolatileRelayConfig` 都定義了相同的 beans：
- `inMemoryProducer`
- `messageBroker` / `inMemoryMessageBroker`
- `relay` / `ezesVolatileRelay`

### 修復方式
從 `SharedInfrastructureConfig` 移除重複的 bean 定義，只保留 Event Storage 相關的 beans：
- `InMemoryMessageDb`
- `InMemoryMessageDbClient`

Message Broker 和 Relay 相關的 beans 由 `VolatileRelayConfig` 負責。

### Skill 改進建議
在 `init-project` 或 `command-sub-agent-prompt.md` 中明確說明：
- `SharedInfrastructureConfig` 只負責 Event Storage
- `VolatileRelayConfig` 負責 Message Broker 和 Relay
- 避免在兩個 Config 中定義相同的 beans

---

## 問題 2: InMemoryMessageBroker API 誤用

### 症狀
```
Unresolved compilation problem:
The method register(BaseUseCaseTest.FakeEventListener) is undefined for the type InMemoryMessageBroker<DomainEventData>
```

### 根本原因
錯誤地假設 `InMemoryMessageBroker` 支持 pub/sub 模式的 `register()` 方法。

實際上 `InMemoryMessageBroker` 只提供：
- `post(message)` - 發布消息
- `poll(fromIndex, maxRecords)` - 輪詢消息
- `size()` - 獲取消息數量

### 修復方式
使用 `InMemoryConsumer` 的 polling 機制：
```java
consumer = new InMemoryConsumer<>(inMemoryMessageBroker);
List<DomainEventData> polled = consumer.poll(lastPolledIndex, 1000);
```

### Skill 改進建議
在 `testing-patterns.md` 或 `framework-api.md` 中添加：
```markdown
## InMemoryMessageBroker API (ezapp 2.0.0)

InMemoryMessageBroker 使用 **polling 機制**，不支持 pub/sub：

```java
// ✅ 正確：使用 polling
InMemoryConsumer<DomainEventData> consumer = new InMemoryConsumer<>(messageBroker);
List<DomainEventData> events = consumer.poll(fromIndex, maxRecords);

// ❌ 錯誤：沒有 register 方法
messageBroker.register(listener);  // 編譯錯誤！
```
```

---

## 問題 3: OutboxMapper.toData() 沒有設置 DomainEventDatas

### 症狀
```
NullPointerException: Cannot invoke "java.util.List.isEmpty()" because the return value of
"tw.teddysoft.ezddd.usecase.port.out.repository.impl.outbox.OutboxData.getDomainEventDatas()" is null
```

### 根本原因
`EzOutboxClient.save()` 直接調用 `data.getDomainEventDatas().size()`，如果 `getDomainEventDatas()` 返回 null 會拋出 NPE。

原始的 `BoardMapper.toData()` 只映射了 aggregate 狀態欄位，沒有處理 domain events。

### 修復方式
在 `toData()` 中添加 domain events 轉換：
```java
@Override
public BoardData toData(Board board) {
    // ... 映射狀態欄位 ...

    // 必須：轉換 domain events
    List<DomainEventData> eventDatas = board.getDomainEvents().stream()
            .map(event -> DomainEventMapper.toData(event))
            .collect(Collectors.toList());
    data.setDomainEventDatas(eventDatas);

    // 必須：設置 stream name
    data.setStreamName("Board-" + board.getId().value());

    return data;
}
```

### Skill 改進建議
在 `outbox-sub-agent-prompt.md` 或 Mapper 範例中強調：
```markdown
## OutboxMapper.toData() 必須設置的欄位

1. **Aggregate 狀態欄位** - id, version, 業務欄位
2. **DomainEventDatas** - 必須！否則 EzOutboxClient.save() 會 NPE
3. **StreamName** - 必須！用於事件發布

```java
// ⚠️ CRITICAL: 這兩行不能省略！
data.setDomainEventDatas(convertEvents(aggregate.getDomainEvents()));
data.setStreamName("AggregateName-" + aggregate.getId().value());
```
```

---

## 問題 4: DomainEventMapper.toDomain() 返回類型

### 症狀
```
Type mismatch: cannot convert from List<Object> to List<DomainEvent>
```

### 根本原因
`DomainEventMapper.toDomain()` 的泛型簽名是 `<T extends InternalDomainEvent> T toDomain(DomainEventData)`，但由於 Java 類型擦除，在 stream 中使用時需要明確轉型。

### 修復方式
```java
// ❌ 編譯錯誤
.map(DomainEventMapper::toDomain)

// ✅ 正確：明確轉型
.map(data -> (DomainEvent) DomainEventMapper.toDomain(data))
```

### Skill 改進建議
在 `framework-api.md` 中添加：
```markdown
## DomainEventMapper 使用注意事項

由於 Java 類型擦除，在 stream 中使用時需要明確轉型：

```java
// 在 stream 中使用
List<DomainEvent> events = eventDatas.stream()
    .map(data -> (DomainEvent) DomainEventMapper.toDomain(data))
    .collect(Collectors.toList());
```
```

---

## 問題 5: test-inmemory Profile 缺少配置

### 症狀
```
Failed to determine a suitable driver class
Error creating bean with name 'flyway'
Error creating bean with name 'entityManagerFactory'
```

### 根本原因
`test-inmemory` profile 沒有禁用 JPA/Flyway 自動配置，Spring Boot 嘗試連接不存在的資料庫。

### 修復方式
創建 `application-test-inmemory.properties`：
```properties
# Disable DataSource auto-configuration
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,\
  org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,\
  org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration

spring.data.jpa.repositories.enabled=false
```

### Skill 改進建議
在 `init-project` 流程中自動生成此配置檔案，或在 `testing-patterns.md` 中說明。

---

## 問題 6: getCapturedEvents() 沒有使用 lastPolledIndex

### 症狀
```
AssertionError: Expecting empty but was: [BoardCreated[...]]
```

`clearCapturedEvents()` 後，`getCapturedEvents()` 仍然返回舊事件。

### 根本原因
`getCapturedEvents()` 總是從 index 0 開始讀取：
```java
// ❌ 錯誤：忽略 lastPolledIndex
List<DomainEventData> polled = consumer.poll(0, 1000);
```

而 `clearCapturedEvents()` 只是更新了 `lastPolledIndex`。

### 修復方式
```java
// ✅ 正確：從 lastPolledIndex 開始讀取
List<DomainEventData> polled = consumer.poll(lastPolledIndex, 1000);
```

### Skill 改進建議
在 `BaseUseCaseTest` 範例中確保 polling 邏輯正確。

---

## 總結：Skill 改進優先級

| 優先級 | 問題 | 影響 | 建議改進位置 |
|--------|------|------|-------------|
| **P0** | OutboxMapper 必須設置 DomainEventDatas | 運行時 NPE | `outbox-sub-agent-prompt.md` |
| **P0** | InMemoryMessageBroker 使用 polling | 編譯錯誤 | `framework-api.md`, `testing-patterns.md` |
| **P1** | SharedInfrastructureConfig vs VolatileRelayConfig | Bean 衝突 | `init-project`, 架構文件 |
| **P1** | test-inmemory profile 配置 | Context 載入失敗 | `init-project` 自動生成 |
| **P2** | DomainEventMapper 類型轉換 | 編譯錯誤 | `framework-api.md` |
| **P2** | BaseUseCaseTest polling 邏輯 | 測試失敗 | 範例程式碼 |

---

## 參考資料

- `EzOutboxClient.java` 源碼（save 方法第 26 行）
- `InMemoryMessageBroker.java` 源碼（只有 post/poll/size 方法）
- ADR-021: Profile-Based Testing
- ADR-044: Profile-Based DI 規範
