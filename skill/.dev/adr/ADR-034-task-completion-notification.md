# ADR-019: Task Completion Notification Mechanism

## Status
Accepted

## Context
當 AI 助手（Claude）執行耗時較長的任務時，使用者可能不會一直在電腦前等待。需要一個機制在任務完成時通知使用者，讓使用者可以去做其他事情。

## Decision
使用 macOS 內建的 `say` 指令提供語音通知，作為主要的任務完成通知機制。

### 實作方式
```bash
# 基本通知
say "任務完成"

# 階段性通知
say "後端實作完成"
say "前端實作完成"
say "測試全部通過"

# 使用台灣中文語音
say -v Meijia "任務完成"
```

### 通知時機
1. **任務全部完成時** - 必須通知
2. **遇到錯誤需要處理時** - 必須通知
3. **重要里程碑完成時** - 可選通知
4. **需要使用者確認時** - 必須通知

### 使用者指定方式
使用者在交代任務時可以明確指定：
- "完成後通知我"
- "做完跟我說一聲"
- "每個步驟都通知"

## Consequences

### 優點
1. **零成本** - 使用 macOS 內建功能，無需額外安裝
2. **即時性** - 語音通知立即可聽到
3. **簡單有效** - 一行指令即可實現
4. **支援中文** - macOS 有多個中文語音可選
5. **不干擾** - 語音通知不會中斷當前工作

### 缺點
1. **平台限制** - 僅限 macOS 使用者
2. **需要音量開啟** - 靜音狀態下無效
3. **無持久性** - 錯過就沒有記錄
4. **無遠端通知** - 必須在電腦附近才能聽到

### 替代方案（未採用）
1. **瀏覽器通知** - 需要權限設定，且容易被忽略
2. **Slack/Discord Webhook** - 需要額外設定，增加複雜度
3. **Email 通知** - 延遲較高，不夠即時
4. **檔案標記** - 需要主動檢查，失去通知意義

## Implementation Notes

### 標準通知腳本
```bash
#!/bin/bash
# 任務開始
say "開始執行任務"

# 執行任務...

# 任務完成
if [ $? -eq 0 ]; then
    say "任務完成"
else
    say "任務失敗，請檢查錯誤"
fi
```

### 跨平台相容性考慮
```bash
# 檢查系統類型
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    say "任務完成"
elif command -v espeak &> /dev/null; then
    # Linux with espeak
    espeak "Task completed"
else
    # Fallback to terminal bell
    echo -e "\a"
    echo ">>> 任務完成 <<<"
fi
```

## Related Decisions
- ADR-005: AI Task 執行 SOP - 定義了任務執行流程
- ADR-013: Task Results Tracking - 定義了任務結果記錄方式

## References
- [macOS say command documentation](https://ss64.com/osx/say.html)
- [Text to Speech on macOS](https://support.apple.com/guide/mac-help/use-text-to-speech-mchlp2290/mac)

## Decision Date
2025-01-20

## Last Modified
2025-01-20

## Author
AI Assistant (Claude) with User