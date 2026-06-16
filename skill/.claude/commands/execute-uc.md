---
description: Execute use case JSON specification to generate DDD code (invokes UC Executor module)
---

# Execute UseCase Spec: `$ARGUMENTS`

**This command invokes the `ezddd-java` skill's UC Executor module.**

For complete workflow details, see: `.claude/skills/ezddd-java/SKILL.md`

---

## Arguments

| 參數 | 說明 | 範例 |
|------|------|------|
| `<spec-path>` | JSON spec 檔案路徑 | `.dev/specs/product/usecase/create-product.json` |
| `--dry-run` | 只驗證 spec，不產生程式碼 | `execute-uc --dry-run .../create-product.json` |
| `--controller` | 額外產生 Controller + Controller Test（Adapter 層） | `execute-uc --controller .../create-product.json` |

### 使用範例

```bash
# Command UseCase（有 domainEvent）
/execute-uc .dev/specs/product/usecase/create-product.json

# Query UseCase（有 projections）
/execute-uc .dev/specs/product/usecase/get-products.json

# Reactor（有 events + dependencies）
/execute-uc .dev/specs/pbi/usecase/reactor/notify-pbi-reactor.json

# 含 Controller 層
/execute-uc --controller .dev/specs/product/usecase/create-product.json

# Dry-run（只驗證 spec schema）
/execute-uc --dry-run .dev/specs/sprint/usecase/start-sprint.json
```

---

For spec types, execution phases, quality gates, and failure conditions, see:
- `.claude/skills/ezddd-java/SKILL.md` § UseCase Spec Executor
- `.claude/skills/ezddd-java/references/uc-executor/uc-workflow.md`
