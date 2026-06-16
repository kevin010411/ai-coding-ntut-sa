# CatchUpRelay Checkpoint vs Sequence Reset 競態條件

## 問題描述

在 OutboxTestSuite 中，`@DirtiesContext(AFTER_EACH_TEST_METHOD)` 導致每個測試方法後重建 Spring Context。新 Context 的 `EzesCatchUpRelay` 在初始化時立即開始 poll DB，但 `setUpEventCapture()` 中的 messages table 清理（含 sequence reset）在 relay 啟動之後才執行，造成 checkpoint 與 sequence 不一致。

## 症狀

- **第一個測試**：正常通過
- **第二個測試**：`ConditionTimeoutException`，event handler 收到 0 個事件

```
org.awaitility.core.ConditionTimeoutException: Assertion condition
Expecting actual: 0 to be greater than or equal to: 1
within 10 seconds.
```

## 根本原因（時序圖）

```
第二個測試啟動時序：

1. @DirtiesContext 銷毀舊 Context
2. Spring 建立新 Context
   └─ CatchupRelayConfig 建立 EzesCatchUpRelay（checkpoint = 0）
   └─ Relay 立即 poll DB，發現第一個測試的 event（position = 1）
   └─ Relay 處理 event，checkpoint 推進到 1
3. @BeforeEach → setUpEventCapture()
   └─ DELETE FROM message_store.messages        ← 資料清空
   └─ ALTER SEQUENCE ... RESTART WITH 1         ← ⚠️ sequence 回到 1
   └─ 建立 consumer、sleep 200ms、clearHandledEvents
4. 測試寫入新 event → global_position = 1      ← sequence 從 1 重新開始
5. Relay checkpoint = 1，跳過 position = 1     ← ❌ 永遠看不到新 event！
```

**關鍵**：Relay 用 `global_position` 作為 checkpoint。Reset sequence 讓新 event 的 position 回到已處理過的值。

## 為什麼第一個測試不受影響

第一個測試使用的是初始 Context。此時 messages table 可能是空的（或在 `setUpEventCapture()` 中被清空），relay 的 checkpoint 還在 0，新 event 的 position 為 1（> 0），所以能正常讀取。

## 解決方案

**只刪除資料，不重設 sequence：**

```java
// ✅ 正確
jdbcTemplate.execute("DELETE FROM message_store.messages");

// ❌ 錯誤：會導致 checkpoint 與 position 不一致
jdbcTemplate.execute("ALTER SEQUENCE message_store.messages_global_position_seq RESTART WITH 1");
```

不重設 sequence 時，新 event 的 `global_position` 會從 N+1 繼續遞增（N 為 relay 最後處理的 position），保證永遠大於 checkpoint。

## 通用原則

> **永遠不要在有 CatchUpRelay 運行的環境中重設 message store 的 sequence。**
>
> CatchUpRelay 依賴 `global_position` 的單調遞增特性。重設 sequence 破壞了這個不變式。

## 適用範圍

- `EzesCatchUpRelay`（Outbox profile）
- 任何基於 position/offset checkpoint 的 polling consumer
- 類似 Kafka consumer offset 的機制：不能在 consumer 運行時重設 topic 的 offset

## 發現日期

2026-03-14

## 相關文件

- `src/test/java/.../test/base/BaseUseCaseTest.java` — 修正位置
- `src/main/java/.../connectionframe/CatchupRelayConfig.java` — relay 建立與啟動
- `.dev/lessons/EZES-VOLATILE-RELAY-SINGLETON-TRAP.md` — 相關的 relay 測試隔離問題
