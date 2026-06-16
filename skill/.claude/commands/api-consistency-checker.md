---
name: api-consistency-checker
description: Check API consistency between JSON specs, Backend Controllers, and Frontend APIs
---

# API Consistency Checker

Automatically checks consistency between **JSON Specs**, **Backend Controllers**, and **Frontend API calls**.

## Usage

```
/api-consistency-checker [options] [module]
```

## Options

- `--no-spec`: Frontend ↔ Backend only (skip spec comparison)
- `--coverage`: Show only spec implementation coverage (no field comparison)

## Examples

```bash
# Full three-way check (default)
/api-consistency-checker

# Check specific module only
/api-consistency-checker product
/api-consistency-checker sprint
/api-consistency-checker pbi

# Frontend ↔ Backend only (legacy mode)
/api-consistency-checker --no-spec

# Coverage report only
/api-consistency-checker --coverage
```

## What This Checks

### Three-Way Comparison
1. **Spec → Backend**: Check if each spec has backend implementation
2. **Spec → Frontend**: Check if each spec has frontend API consumer
3. **Field Matching**: Compare request/response fields across all three

### Detected Issues
- Missing backend implementations
- Missing frontend API calls
- Orphan implementations (no spec)
- Path mismatches
- HTTP method mismatches
- Request body field mismatches
- Missing required headers

## Report Format

```
API Consistency Report
======================

📋 Spec Coverage Summary:
┌──────────────────┬───────┬──────────┬──────────┐
│ Category         │ Total │ Backend  │ Frontend │
├──────────────────┼───────┼──────────┼──────────┤
│ Command (CBF)    │ 25    │ 23 (92%) │ 20 (80%) │
│ Query (IDF)      │ 15    │ 15 (100%)│ 15 (100%)│
│ Workflow (SWF)   │ 5     │ 4 (80%)  │ 3 (60%)  │
└──────────────────┴───────┴──────────┴──────────┘

✅ Fully Implemented: 35
⚠️ Backend Only: 3
⚠️ Frontend Only: 2
❌ Spec Only: 5
```

## File Locations

- **Specs**: `.dev/specs/**/controller.json`
- **Backend**: `src/main/java/**/adapter/in/rest/springboot/*Controller.java`
- **Frontend**: `frontend/src/api/*.ts`

## See Also

- `.claude/skills/api-consistency-checker/SKILL.md` - Full skill documentation
- `.claude/skills/api-consistency-checker/spec-patterns.md` - Spec parsing rules
- `.claude/skills/api-consistency-checker/backend-patterns.md` - Backend parsing rules
- `.claude/skills/api-consistency-checker/frontend-patterns.md` - Frontend parsing rules
