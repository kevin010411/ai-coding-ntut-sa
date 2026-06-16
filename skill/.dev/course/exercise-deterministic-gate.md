整體防護架構圖

⏺ Session 開始
│
├── SessionStart hook (deterministic, 自動觸發)
│   └── 記錄 Java 檔案基線
│       git status --porcelain | grep '\.java$' > .claude/tmp/gate25-baseline.txt
│       清除舊 marker: rm -f .gate25-markers/*.marker.json
│
│
├── /execute-uc spec.json
│   │
│   ├── Phase 0-4: LLM 讀 spec → 產生程式碼 → 編譯 → 測試
│   │
│   ├── Phase 5: LLM 呼叫 validate-generated-code.sh (⚠️  非 deterministic，LLM 可能跳過)
│   │   │
│   │   ├── 0 CRITICAL
│   │   │   └── 腳本自動寫入 .gate25-markers/product.marker.json
│   │   │       {
│   │   │         "aggregate": "product",
│   │   │         "files_checksum": "sha256:abc123...",
│   │   │         "timestamp": "2026-03-16T10:30:00Z",
│   │   │         "critical_count": 0
│   │   │       }
│   │   │
│   │   └── CRITICAL found
│   │       └── 不寫 marker，LLM 進 fix loop
│   │
│   └── Phase 6-7: Spec compliance → 報告
│
│
└── LLM 嘗試結束
│
└── Stop hook: gate25-stop-guard.sh (deterministic, 自動觸發)
│
│  Step 1: 算出本次 session 的 Java 變動
│  ┌─────────────────────────────────────────────┐
│  │ current = git status --porcelain | grep java │
│  │ baseline = cat .claude/tmp/gate25-baseline.txt│
│  │ diff = current - baseline                    │
│  └─────────────────────────────────────────────┘
│
├── diff 為空（本次 session 沒動 Java）
│   └── exit 0 ✅ 放行
│
├── diff 不為空 + 無 marker
│   └── exit 2 ⛔ 「偵測到 Java 變動但 Gate 2.5 未執行」
│
├── diff 不為空 + 有 marker + 重算 checksum 一致
│   └── exit 0 ✅ 放行
│
└── diff 不為空 + 有 marker + checksum 不一致
└── exit 2 ⛔ 「驗證後程式碼被修改，重新執行 Gate 2.5」

三個組件，各自職責：

┌────────────────────────────┬──────────┬─────────────────────┬───────────────────┐
│            組件            │ 觸發方式 │        職責         │  Deterministic?   │
├────────────────────────────┼──────────┼─────────────────────┼───────────────────┤
│ SessionStart hook          │ 自動     │ 記基線、清舊 marker │        ✅         │
├────────────────────────────┼──────────┼─────────────────────┼───────────────────┤
│ validate-generated-code.sh │ LLM 呼叫 │ 檢查 + 寫 marker    │   ⚠️  檢查本身     │
│                            │          │                     │ ✅，但呼叫靠 LLM  │
├────────────────────────────┼──────────┼─────────────────────┼───────────────────┤
│                            │          │ 驗基線 diff + 驗    │                   │
│ Stop hook                  │ 自動     │ marker + 驗         │        ✅         │
│                            │          │ checksum            │                   │
└────────────────────────────┴──────────┴─────────────────────┴───────────────────┘

LLM 唯一能跳過的是中間那步，但跳過的後果是「Stop hook 擋住你」。

