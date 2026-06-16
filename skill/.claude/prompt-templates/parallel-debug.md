# Parallel Debug Agent — Prompt Template

> 使用方式：複製下方 prompt，替換 `[BUG DESCRIPTION]` 後貼到 Claude Code

## Template

```
Investigate this bug using 3 parallel investigation tracks:

**Bug**: [BUG DESCRIPTION]

**IMPORTANT**: Before investigating, read CLAUDE.md and check .claude/skills/
for any existing documentation about this topic. Use project docs as primary reference.

Launch 3 parallel Task agents simultaneously:

**Track 1 — Configuration Analysis** (subagent_type: Explore):
- Check all profile configurations (application-*.yml), Spring configs
- Compare against conventions in .dev/lessons/ and .dev/adr/
- Look for profile/environment mismatches
- Check for @ActiveProfiles violations (ADR-021)

**Track 2 — Code Logic Trace** (subagent_type: Explore):
- Trace execution path from entry point through all layers
- Check recent git changes: `git log --oneline -10 --all -- <relevant-paths>`
- Look for null handling, type mismatches, missing event handlers
- Verify Clean Architecture layer boundaries

**Track 3 — Test Environment** (subagent_type: Bash):
- Run related tests in BOTH profiles:
  SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest=<TestClass> -q
  SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest=<TestClass> -q
- Check if issue is profile-specific
- Verify test isolation (@DirtiesContext presence)

After all 3 tracks complete, synthesize:

| Track | Hypothesis | Evidence | Confidence |
|-------|-----------|----------|------------|
| Config | ... | ... | 0-100 |
| Logic | ... | ... | 0-100 |
| Test Env | ... | ... | 0-100 |

Then: Fix the highest-confidence root cause → Write regression test →
Run dual-profile verification → Show results.
```

## When to Use

- Bug 原因不明，需要多角度同時調查
- 測試在某個 profile 通過但另一個失敗
- 間歇性失敗（可能是 test isolation 問題）
- 跨層問題（Controller → UseCase → Entity）

## Why 3 Tracks?

報告數據顯示 20 個 session 因「初始方法錯誤」浪費時間。
平行 3 條線同時探索，最慢的那條也不會超過單線探索的時間，
但覆蓋面是 3 倍。
