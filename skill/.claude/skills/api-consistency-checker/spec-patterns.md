# JSON Spec Patterns (controller.json)

This document describes how to parse JSON controller specifications in this project.

## File Location

All spec files are located in:
```
.dev/specs/**/controller.json
```

Pattern: `.dev/specs/{aggregate}/adapter/controller.json`

### Frame Types
- **cbf** (Command-Behavior Frame): Write operations (POST, PUT, DELETE)
- **idf** (Information-Display Frame): Read operations (GET)
- **swf** (State-Workflow Frame): State transition operations

## YAML Structure

### Basic Structure
```yaml
# $schema: path/to/controller.schema.json
controller:
  name: ControllerClassName

endpoint:
  method: HTTP_METHOD
  path: /v1/api/resource

request:
  path_params: []
  headers: []
  body:
    type: RequestTypeName
    fields: []

mapping:
  use_case_input: InputClassName
  rules: []

response:
  success:
    status: HTTP_STATUS_CODE
    headers: []
    body:
      type: ResponseTypeName
      fields: []

error_responses:
  delegated_to: machine/use-case.yaml#error_mapping

notes: |
  Description of the endpoint
```

## Parsing Rules

### 1. Extract Controller Info
```yaml
controller:
  name: CreateProductController
```
- **Controller name**: `CreateProductController`
- Use this to match with backend `*Controller.java` file

### 2. Extract Endpoint Definition
```yaml
endpoint:
  method: POST
  path: /v1/api/products
```
- **HTTP method**: `POST`
- **Full path**: `/v1/api/products`

Path with variables:
```yaml
endpoint:
  method: DELETE
  path: /v1/api/products/{productId}
```
- **HTTP method**: `DELETE`
- **Full path**: `/v1/api/products/{productId}`
- **Path variables**: Extract `{productId}` from path

### 3. Extract Path Parameters
```yaml
request:
  path_params:
    - name: productId
      type: String
    - name: sprintId
      type: String
```
- **Path params**: `[productId, sprintId]`
- These should match `{productId}` and `{sprintId}` in the path

### 4. Extract Headers
```yaml
request:
  headers:
    - name: Idempotency-Key
      type: String
      required: false
      description: Client-supplied idempotency key
    - name: X-User-Id
      type: String
      required: true
      description: User performing the action
```
- **Optional headers**: `Idempotency-Key`
- **Required headers**: `X-User-Id`

### 5. Extract Request Body
```yaml
request:
  body:
    type: CreateProductRequest
    fields:
      - name: productId
        type: String
        optional: true
        description: Client-supplied optional product ID
      - name: name
        type: String
        constraints: ["non_blank", "max_len_100"]
        description: Product display name
      - name: userId
        type: String
        constraints: ["non_blank", "max_len_100"]
        description: User ID of the creator
```
- **Request body type**: `CreateProductRequest`
- **Fields**:
  - `productId` (String, optional)
  - `name` (String, required - has constraints)
  - `userId` (String, required - has constraints)

Field optionality rules:
- If `optional: true` → optional field
- If `constraints` contains `non_blank` or `non_null` → required field
- Default → required field

### 6. Extract Response Definition
```yaml
response:
  success:
    status: 202
    headers:
      - name: Location
        type: String
        source: generated
      - name: Operation-Id
        type: String
        source: generated
    body:
      type: AcceptedResponse
      fields:
        - name: operationId
          type: String
        - name: status
          type: String
```
- **Success status**: `202`
- **Response headers**: `Location`, `Operation-Id`
- **Response body type**: `AcceptedResponse`
- **Response fields**: `operationId`, `status`

For queries (GET):
```yaml
response:
  success:
    status: 200
    body:
      type: List<readonlyProduct>
```
- **Success status**: `200`
- **Response body type**: `List<readonlyProduct>`

## HTTP Method Mapping by Frame Type

| Frame Type | Typical Method | Description |
|------------|---------------|-------------|
| cbf (create) | POST | Create new resource |
| cbf (update) | PUT | Update existing resource |
| cbf (delete) | DELETE | Delete resource |
| cbf (action) | POST | Trigger action on resource |
| idf | GET | Query resource(s) |
| swf | POST | State transition |

## Example Spec Parsing Output

For `create-product/machine/controller.yaml`:
```
┌─────────────────────────┬──────────────────────────────────────────────────┐
│ Property                │ Value                                            │
├─────────────────────────┼──────────────────────────────────────────────────┤
│ Controller              │ CreateProductController                          │
│ HTTP Method             │ POST                                             │
│ Path                    │ /v1/api/products                                 │
│ Path Params             │ -                                                │
│ Required Headers        │ -                                                │
│ Optional Headers        │ Idempotency-Key                                  │
│ Request Body Type       │ CreateProductRequest                             │
│ Request Fields          │ productId (opt), name (req), userId (req)        │
│ Response Status         │ 202                                              │
│ Response Body Type      │ AcceptedResponse                                 │
│ Frame Type              │ swf (from path)                                  │
└─────────────────────────┴──────────────────────────────────────────────────┘
```

## Constraint Mapping

Spec constraints map to validation annotations:

| Spec Constraint | Backend Annotation | Frontend Validation |
|-----------------|-------------------|---------------------|
| `non_blank` | `@NotBlank` | `required && value.trim()` |
| `non_null` | `@NotNull` | `required` |
| `max_len_N` | `@Size(max=N)` | `maxLength: N` |
| `min_len_N` | `@Size(min=N)` | `minLength: N` |
| `positive` | `@Positive` | `value > 0` |
| `email` | `@Email` | `pattern: email` |

## Aggregating Specs by Module

When checking by module, filter specs by path pattern:

```
Module: product
Path pattern: .dev/specs/product/adapter/controller.json

Module: sprint
Path pattern: .dev/specs/sprint/adapter/controller.json

Module: pbi
Path pattern: .dev/specs/pbi/adapter/controller.json
```

## Matching Spec to Implementation

### Match to Backend Controller
1. Find `*Controller.java` where class name matches `controller.name`
2. Or find controller where path + method matches `endpoint.path` + `endpoint.method`

### Match to Frontend API
1. Find RTK Query endpoint where URL matches `endpoint.path`
2. And HTTP method matches `endpoint.method`

## Special Cases

### No Request Body (GET, DELETE)
```yaml
request:
  path_params:
    - name: productId
      type: String
  # No body section
```

### Query Parameters
```yaml
request:
  query_params:
    - name: status
      type: String
      required: false
    - name: limit
      type: Integer
      required: false
      default: 10
```

### Multiple Path Parameters
```yaml
endpoint:
  path: /v1/api/products/{productId}/sprints/{sprintId}/pbis/{pbiId}

request:
  path_params:
    - name: productId
      type: String
    - name: sprintId
      type: String
    - name: pbiId
      type: String
```

## Caveats

1. **Schema Version**: Check `$schema` comment for version compatibility
2. **Delegated Errors**: `error_responses.delegated_to` points to use-case.yaml for error definitions
3. **Optional vs Required**: Field without `optional: true` and without `non_blank`/`non_null` constraint is ambiguous - treat as required
4. **Nested Objects**: Some request bodies have nested objects - compare only top-level fields for consistency check
