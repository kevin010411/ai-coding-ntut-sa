# E2E Test Phased Prompt Template

> 使用方式：複製下方 prompt，替換 `[Feature]` 後貼到 Claude Code

## Template

```
Create E2E tests for [Feature] management. Work in 3 phases:

**Phase 1 — Analyze** (stop after this phase and show me the plan):
- Read existing E2E tests in frontend/tests/e2e/ to understand patterns
- Identify all user flows for [Feature] that need coverage
- List which components need data-testid attributes
- Output a test plan table: | Test Case | User Flow | Priority |

**Phase 2 — Implement** (after I approve the plan):
- Add data-testid attributes to components that need them
- Extend test helpers in frontend/tests/e2e/helpers/ if needed
- Write the E2E test file following existing naming conventions
- Each test should be independent and use test-data-factory

**Phase 3 — Verify** (run tests and fix):
- Run the tests with: cd frontend && npm run test:e2e -- --grep "[Feature]"
- Fix any failures (max 3 retry cycles)
- Show final results table: | Test | Status | Notes |
```

## Why Phased?

1. **Phase 1 停下來確認** → 避免 Claude 走錯方向後浪費整個 session
2. **Phase 2 有明確範圍** → 基於已核准的計畫實作，不會過度探索
3. **Phase 3 有收尾標準** → 測試必須通過，不會半途而廢
