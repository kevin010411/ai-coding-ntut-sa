# Backend Spring Boot Controller Patterns

This document describes how to parse Spring Boot REST Controllers in this project.

## File Location

All backend controllers are located in:
```
src/main/java/**/adapter/in/rest/springboot/*Controller.java
```

Pattern: `{aggregate}/adapter/in/rest/springboot/{UseCaseName}Controller.java`

## Controller Structure

### Basic Controller Pattern
```java
package tw.teddysoft.aiscrum.[aggregate].adapter.in.rest.springboot;

@RestController
@RequestMapping("/v1/api/[resource]")
public class [UseCaseName]Controller {

    private final [UseCase] useCase;

    public [UseCaseName]Controller([UseCase] useCase) {
        this.useCase = Objects.requireNonNull(useCase);
    }

    @[HttpMethod]Mapping([path])
    public ResponseEntity<[ResponseType]> [methodName](...) {
        // ...
    }
}
```

## Parsing Rules

### 1. Extract Class-Level Base Path

Look for `@RequestMapping` on the class:
```java
@RestController
@RequestMapping("/v1/api/products")
public class CreateProductController {
```
- **Base path**: `/v1/api/products`

### 2. Extract HTTP Method and Path

#### GET Mapping
```java
@GetMapping
public ResponseEntity<List<ProductReadOnly>> getProducts() {
```
- **HTTP method**: GET
- **Path**: (base path only) `/v1/api/products`

```java
@GetMapping("/{id}")
public ResponseEntity<ProductReadOnly> getProduct(@PathVariable String id) {
```
- **HTTP method**: GET
- **Path**: `/v1/api/products/{id}`

#### POST Mapping
```java
@PostMapping
public ResponseEntity<AcceptedResponse> createProduct(@Valid @RequestBody CreateProductRequest request) {
```
- **HTTP method**: POST
- **Path**: `/v1/api/products`
- **Request body**: `CreateProductRequest`

```java
@PostMapping("/{productId}/sprints")
public ResponseEntity<AcceptedResponse> createSprint(
    @PathVariable String productId,
    @Valid @RequestBody CreateSprintRequest request) {
```
- **HTTP method**: POST
- **Path**: `/v1/api/products/{productId}/sprints`
- **Path variables**: `productId`
- **Request body**: `CreateSprintRequest`

#### PUT Mapping
```java
@PutMapping("/{id}")
public ResponseEntity<ProductReadOnly> updateProduct(
    @PathVariable String id,
    @Valid @RequestBody UpdateProductRequest request) {
```
- **HTTP method**: PUT
- **Path**: `/v1/api/products/{id}`
- **Path variables**: `id`
- **Request body**: `UpdateProductRequest`

#### DELETE Mapping
```java
@DeleteMapping("/{id}")
public ResponseEntity<AcceptedResponse> deleteProduct(
    @PathVariable String id,
    @RequestHeader("X-User-Id") String userId) {
```
- **HTTP method**: DELETE
- **Path**: `/v1/api/products/{id}`
- **Path variables**: `id`
- **Required headers**: `X-User-Id`

### 3. Extract Path Variables

Pattern: `@PathVariable [Type] [name]`
```java
@GetMapping("/{productId}/sprints/{sprintId}")
public ResponseEntity<SprintReadOnly> getSprint(
    @PathVariable String productId,
    @PathVariable String sprintId) {
```
- **Path variables**: `productId`, `sprintId`
- **Full path**: `/v1/api/products/{productId}/sprints/{sprintId}`

### 4. Extract Query Parameters

Pattern: `@RequestParam [Type] [name]`
```java
@GetMapping
public ResponseEntity<List<ProductBacklogItemReadOnly>> getPbis(
    @RequestParam(required = false) String sprintId,
    @RequestParam(defaultValue = "10") int limit) {
```
- **Query params**:
  - `sprintId` (optional)
  - `limit` (optional, default: 10)

### 5. Extract Request Body

Pattern: `@RequestBody [Type] [name]`
```java
@PostMapping
public ResponseEntity<AcceptedResponse> create(
    @Valid @RequestBody CreateProductRequest request) {
```

Request body class structure:
```java
public static class CreateProductRequest {
    @JsonProperty("productId")
    private String productId;

    @NotBlank(message = "Product name is required")
    @Size(min = 1, max = 100)
    @JsonProperty("name")
    private String name;

    @NotBlank(message = "User ID is required")
    @JsonProperty("userId")
    private String userId;

    // getters and setters
}
```

Extract fields:
- `productId` (String, optional - no @NotBlank)
- `name` (String, required - has @NotBlank)
- `userId` (String, required - has @NotBlank)

### 6. Extract Required Headers

Pattern: `@RequestHeader [Type] [name]`
```java
@DeleteMapping("/{id}")
public ResponseEntity<AcceptedResponse> delete(
    @PathVariable String id,
    @RequestHeader("X-User-Id") String userId) {
```
- **Required header**: `X-User-Id`

## HTTP Method Annotations

| Annotation | HTTP Method |
|------------|-------------|
| `@GetMapping` | GET |
| `@PostMapping` | POST |
| `@PutMapping` | PUT |
| `@DeleteMapping` | DELETE |
| `@PatchMapping` | PATCH |

## Response Types

Common response patterns:
```java
// Query - returns data
ResponseEntity<ProductReadOnly>
ResponseEntity<List<ProductReadOnly>>

// Command - returns accepted response
ResponseEntity<AcceptedResponse>

// Void response
ResponseEntity<Void>
```

## Example Output

For Product controllers:
```
┌──────────────────────────────┬────────┬─────────────────────┬──────────────────────┐
│ Controller                   │ Method │ Path                │ Request Body         │
├──────────────────────────────┼────────┼─────────────────────┼──────────────────────┤
│ GetProductsController        │ GET    │ /v1/api/products    │ -                    │
│ GetProductController         │ GET    │ /v1/api/products/{id}│ -                   │
│ CreateProductController      │ POST   │ /v1/api/products    │ CreateProductRequest │
│ UpdateProductController      │ PUT    │ /v1/api/products/{id}│ UpdateProductRequest│
│ DeleteProductController      │ DELETE │ /v1/api/products/{id}│ -                   │
└──────────────────────────────┴────────┴─────────────────────┴──────────────────────┘
```

## Validation Annotations

When comparing request bodies, note these validation annotations:
- `@NotBlank` - Required string, not null/empty
- `@NotNull` - Required, not null
- `@Size(min, max)` - String length constraints
- `@Valid` - Nested validation
- `@Min`, `@Max` - Number range

## Nested Request Classes

Request classes are typically defined as inner classes:
```java
@RestController
public class CreateProductController {

    // Inner request class
    public static class CreateProductRequest {
        // fields
    }

    // Inner response class
    public static class AcceptedResponse {
        // fields
    }
}
```

## Controller Naming Convention

This project follows the pattern:
- **Command**: `[Action][Entity]Controller` (e.g., `CreateProductController`)
- **Query**: `Get[Entity/Entities]Controller` (e.g., `GetProductsController`)

Each controller typically handles one endpoint (one use case per controller).

## Read-only Response ID Naming Convention (CRITICAL)

**後端 read-only response 的 ID 查詢欄位必須使用 `[aggregate]Id` 命名，禁止使用泛用的 `id`。**

```java
// ✅ CORRECT — 使用 aggregateId
public class ProductReadOnly { public String getProductId() { ... } }
public class SprintReadOnly { public String getSprintId() { ... } }

// ❌ WRONG — 泛用 id 會導致前端 undefined
public class ProductReadOnly { public String getId() { ... } }
```

**原因**：
- Java record 欄位名直接決定 JSON key（`id` → `"id"`，`productId` → `"productId"`）
- 前端 TypeScript read model 介面必須與 JSON key 一對一對應
- 使用泛用 `id` 會導致前後端欄位名不一致，造成 `undefined` 錯誤
- DDD 語意：`productId` 比 `id` 更明確表達 aggregate identity

**適用範圍**：所有 query response 的 `*ReadOnly` 類別。

## Caveats

1. **Multiple Mappings**: Some controllers may have multiple endpoints in one class.
2. **Path Composition**: Final path = class `@RequestMapping` + method mapping value.
3. **Optional Path Variables**: Some `@PathVariable` may have `required = false`.
4. **Inner Classes**: Request/Response DTOs are often inner static classes.
