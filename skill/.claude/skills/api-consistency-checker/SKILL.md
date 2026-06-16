---
name: api-consistency-checker
description: Check consistency between JSON API specs and Spring Boot backend controllers. Use when adding or modifying API endpoints, verifying endpoint coverage, or checking spec-to-controller consistency.
---

# API Consistency Checker Skill

Automatically checks consistency between **JSON Specs** and **Backend Controllers**.

## Architecture

```
                    controller.yaml
                  (Specification - Source of Truth)
                         │
                         ▼
                 Backend Controller
                  (Implementation)
```

## When to Use

Use this skill when:
- Adding new API endpoints
- Modifying existing API calls
- Before deploying to production
- Verifying spec implementation coverage

**Trigger patterns:**
- `check api consistency` - Full spec-to-backend check
- `verify api endpoints`

## Project Structure

### JSON Specs (Source of Truth)
- **Location**: `.dev/specs/**/controller.json`
- **Format**: JSON with endpoint, request, response definitions
- **Role**: Single source of truth for API contracts

### Backend (Spring Boot)
- **Location**: `src/main/java/**/adapter/in/rest/springboot/*Controller.java`
- **Pattern**: `@RestController` with `@RequestMapping`, `@GetMapping`, `@PostMapping`, etc.

## Execution Steps

### Step 1: Scan JSON Specs

For each `controller.json` in `.dev/specs/`:
1. Extract endpoint definition:
   - **Controller name** (e.g., `CreateProductController`)
   - **HTTP method** (GET, POST, PUT, DELETE)
   - **Path** (e.g., `/v1/api/products`)
   - **Path parameters** (from `request.path_params`)
   - **Headers** (from `request.headers`)
   - **Request body** (from `request.body.fields`)
   - **Response status** (from `response.success.status`)
   - **Response body type** (from `response.success.body.type`)

### Step 2: Scan Backend Controllers

For each `*Controller.java`:
1. Extract class-level `@RequestMapping` (base path)
2. Extract method-level mappings
3. Parse request body, path variables, headers

### Step 3: Spec → Backend Comparison

Check if each spec has a corresponding backend implementation:
- Path matches
- HTTP method matches
- Request body fields match
- Path parameters match
- Required headers match

Calculate implementation coverage:
- Total specs defined
- Specs with backend implementation
- Orphan implementations (no spec)

### Step 4: Generate Report

```
API Consistency Report
======================

📋 Spec Coverage Summary:
┌──────────────────┬───────┬──────────┐
│ Category         │ Total │ Backend  │
├──────────────────┼───────┼──────────┤
│ Command (CBF)    │ 25    │ 23 (92%) │
│ Query (IDF)      │ 15    │ 15 (100%)│
│ Workflow (SWF)   │ 5     │ 4 (80%) │
└──────────────────┴───────┴──────────┘

✅ Fully Implemented (Spec + Backend): 42
❌ Spec Only (not implemented): 3

--- Detailed Results ---

❌ Specs Not Implemented in Backend:
   • POST /v1/api/products/{id}/archive
     Spec: .dev/specs/product/usecase/archive-product.json

⚠️ Backend Without Spec (consider adding spec):
   • GET /v1/api/health - HealthCheckController.java
```

## Consistency Rules

### Rule 1: Path Matching
- Spec path must match backend `@RequestMapping` + method mapping
- Spec path must match frontend URL (after baseUrl)
- Path variables: `{id}`, `${id}`, `:id` are equivalent

### Rule 2: HTTP Method Matching
- Spec `endpoint.method` must match backend annotation

### Rule 3: Request Body Matching
- Compare spec `request.body.fields` with backend `@RequestBody` class
- Report missing/extra fields

### Rule 4: Path Parameters
- Spec `request.path_params` must match backend `@PathVariable`

## Scope Options

### Full Three-Way Check (Default)
```
check api consistency
```
Checks all specs against frontend and backend.

### Module-Specific Check
```
check api consistency for product
check api consistency for sprint
check api consistency for pbi
```
Checks only specified module.

### Spec-Only Coverage Report
```
check api coverage
```
Shows only spec implementation coverage without field-level comparison.

## Reference Files

- See `spec-patterns.md` for controller.yaml parsing rules
- See `backend-patterns.md` for Spring Boot Controller parsing rules

## Fix Policy (CRITICAL)

**當 API 一致性檢查發現不一致時，修正策略如下：**

| 修正目標 | 允許自動修改 | 備註 |
|---------|------------|------|
| **Backend Controller** | ✅ 可以 | 後端 controller 是唯一可自動修正的目標 |
| **JSON Spec** | ❌ 禁止 | Spec 是 source of truth，不可因實作不一致而修改 |

> **規則**：發現 Spec 與 Backend 不一致時，應修改後端 Controller 來配合 Spec 定義。

## Known Limitations

1. Cannot detect runtime-only differences (e.g., validation rules beyond spec)
2. Does not verify authentication/authorization requirements
3. Nested object comparison is limited to first-level fields
4. Does not validate response body structure (spec defines type only)
