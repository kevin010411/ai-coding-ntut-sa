---
name: controller-skill
description: |
  Generate Spring Boot REST Controller following Clean Architecture principles.

  Triggered by:
  - code executor (Step 4.6, optional with --controller flag)
  - Direct user request: "generate controller for [use case]"

  Input: Use Case interface definition, controller.yaml specification
  Output:
    - {UseCase}Controller.java (with inner class Request/Response DTOs)
    - ApiError.java (if not exists)

  Controllers are in Adapter Layer and depend on Use Case interfaces.

allowed-tools: Read, Write, Edit, Bash, Glob
---

# Controller Generation Skill

## Overview

This skill generates Spring Boot REST Controllers following Clean Architecture principles.
Controllers are thin adapters that delegate business logic to Use Cases.

---

## INPUT

| Source | Path |
|--------|------|
| Use Case Interface | `src/main/java/{rootPackage}/{aggregate}/usecase/port/in/{UseCase}UseCase.java` |
| Controller Spec | `JSON spec `controller`` (optional) |
| project-config.json | `.dev/project-config.json` |

---

## OUTPUT

| File | Location |
|------|----------|
| Controller | `src/main/java/{rootPackage}/{aggregate}/adapter/in/rest/springboot/{UseCase}Controller.java` |
| ApiError | `src/main/java/{rootPackage}/common/adapter/in/rest/springboot/ApiError.java` (shared) |

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Constructor Injection ONLY (No @Autowired)

```java
// ✅ CORRECT: Constructor injection with Objects.requireNonNull
@RestController
@RequestMapping("/v1/api/products")
public class CreateProductController {

    private final CreateProductUseCase createProductUseCase;

    public CreateProductController(CreateProductUseCase createProductUseCase) {
        this.createProductUseCase = Objects.requireNonNull(createProductUseCase);
    }
}

// ❌ WRONG: Field injection with @Autowired
@RestController
public class CreateProductController {
    @Autowired
    private CreateProductUseCase createProductUseCase;  // FORBIDDEN!
}
```

**Rationale:** Constructor injection makes dependencies explicit and testable.

### Rule 2: /v1/api Prefix for All Endpoints

```java
// ✅ CORRECT: With /v1/api prefix
@RequestMapping("/v1/api/products")

// ❌ WRONG: Missing /v1/api prefix
@RequestMapping("/products")  // WRONG!
@RequestMapping("/api/products")  // WRONG! Missing version
```

### Rule 3: HTTP Status Codes

```java
// ✅ CORRECT: Status codes for each operation type

// Command (POST/PUT/DELETE) - Async operations
@PostMapping
public ResponseEntity<?> createProduct(...) {
    useCase.execute(input);
    return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);  // 202
}

// Query (GET) - Sync operations
@GetMapping("/{id}")
public ResponseEntity<?> getProduct(...) {
    Output output = useCase.execute(input);
    return ResponseEntity.ok(output.getData());  // 200
}

// Create (sync with return data)
@PostMapping
public ResponseEntity<?> createSync(...) {
    return ResponseEntity.status(HttpStatus.CREATED).body(response);  // 201
}

// Delete (sync)
@DeleteMapping("/{id}")
public ResponseEntity<?> deleteSync(...) {
    return ResponseEntity.noContent().build();  // 204
}
```

| Operation | Async | Sync |
|-----------|-------|------|
| POST (Create) | 202 ACCEPTED | 201 CREATED |
| GET (Query) | N/A | 200 OK |
| PUT/PATCH (Update) | 202 ACCEPTED | 200 OK |
| DELETE | 202 ACCEPTED | 204 NO_CONTENT |

### Rule 4: Request/Response DTOs as Inner Classes

```java
// ✅ CORRECT: DTOs as static inner classes
@RestController
@RequestMapping("/v1/api/products")
public class CreateProductController {

    @PostMapping
    public ResponseEntity<?> createProduct(@Valid @RequestBody CreateProductRequest request) {
        // ...
    }

    // Request DTO as static inner class
    public static class CreateProductRequest {
        @NotBlank(message = "Product name is required")
        @JsonProperty("name")
        private String name;

        @NotBlank(message = "User ID is required")
        @JsonProperty("userId")
        private String userId;

        public CreateProductRequest() {}  // Default constructor for JSON

        // Getters and setters
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
    }

    // Response DTO as static inner class
    public static class CreateProductResponse {
        private final String productId;
        private final String status;

        public CreateProductResponse(String productId, String status) {
            this.productId = productId;
            this.status = status;
        }

        public String getProductId() { return productId; }
        public String getStatus() { return status; }
    }
}

// ❌ WRONG: Separate DTO files
// CreateProductRequest.java - WRONG!
public class CreateProductRequest { }
```

**Rationale:** Inner classes improve cohesion and avoid namespace conflicts.

### Rule 5: Thin Controllers - Delegate to UseCase

```java
// ✅ CORRECT: Thin controller delegating to UseCase
@PostMapping
public ResponseEntity<?> createProduct(@Valid @RequestBody CreateProductRequest request) {
    String operationId = UUID.randomUUID().toString();

    // Create input
    CreateProductUseCase.CreateProductInput input = CreateProductUseCase.CreateProductInput.create();
    input.id = request.getProductId();
    input.name = request.getName();
    input.userId = request.getUserId();

    // Delegate to UseCase
    useCase.execute(input);

    // Return response
    return ResponseEntity.status(HttpStatus.ACCEPTED)
        .location(URI.create("/v1/api/products/" + request.getProductId()))
        .body(new CreateProductResponse(request.getProductId(), "ACCEPTED"));
}

// ❌ WRONG: Business logic in controller
@PostMapping
public ResponseEntity<?> createProduct(@Valid @RequestBody CreateProductRequest request) {
    // Business logic in controller - FORBIDDEN!
    if (productRepository.existsByName(request.getName())) {
        throw new DuplicateProductException();
    }
    Product product = new Product(request.getName());
    productRepository.save(product);
}
```

### Rule 6: UseCase Output Handling

```java
// ✅ CORRECT: Handle UseCase output properly
@GetMapping("/{id}")
public ResponseEntity<?> getProduct(@PathVariable String id) {
    String traceId = UUID.randomUUID().toString();

    try {
        GetProductUseCase.GetProductInput input = GetProductUseCase.GetProductInput.create();
        input.productId = id;

        CqrsOutput output = useCase.execute(input);

        if (output.getExitCode() == ExitCode.SUCCESS) {
            return ResponseEntity.ok(output.getData());
        } else {
            String message = output.getMessage();
            if (message != null && message.toLowerCase().contains("not found")) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(new ApiError("RESOURCE_NOT_FOUND", message, traceId));
            }
            return ResponseEntity.badRequest()
                .body(new ApiError("OPERATION_FAILED", message, traceId));
        }
    } catch (Exception e) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(new ApiError("INTERNAL_ERROR", "Unexpected error", traceId));
    }
}

// ❌ WRONG: Ignoring UseCase output
@GetMapping("/{id}")
public ResponseEntity<?> getProduct(@PathVariable String id) {
    useCase.execute(input);  // Output ignored!
    return ResponseEntity.ok().build();  // Always returns success - WRONG!
}
```

### Rule 7: Input Validation with @Valid

```java
// ✅ CORRECT: @Valid on @RequestBody
@PostMapping
public ResponseEntity<?> createProduct(
    @Valid @RequestBody CreateProductRequest request) {
    // Validation happens automatically
}

// ✅ CORRECT: Manual validation for path variables
@GetMapping("/{id}")
public ResponseEntity<?> getProduct(@PathVariable String id) {
    if (id == null || id.trim().isEmpty() || "null".equalsIgnoreCase(id)) {
        return ResponseEntity.badRequest()
            .body(new ApiError("INVALID_ID", "ID cannot be null or empty", traceId));
    }
}
```

### Rule 7b: @Size Constraints on String Fields

<!-- @authority: request_dto_validation | source: patterns/adapter/controller.md -->

Request DTO string fields **SHOULD** have `@Size` constraints to prevent oversized payloads:

| Field Type | Required Annotations |
|-----------|---------------------|
| ID fields | `@NotBlank` |
| Name/Title (user input) | `@NotBlank` + `@Size(max = 255)` |
| Description (free text) | `@Size(max = 2000)` |
| Collection | `@Size(max = 100)` |

```java
public static class CreateProductRequest {
    @NotBlank(message = "Product ID is required")
    @JsonProperty("productId")
    private String productId;

    @NotBlank(message = "Product name is required")
    @Size(max = 255, message = "Name must not exceed 255 characters")
    @JsonProperty("name")
    private String name;

    @Size(max = 2000, message = "Description must not exceed 2000 characters")
    @JsonProperty("description")
    private String description;

    @NotBlank(message = "User ID is required")
    @JsonProperty("userId")
    private String userId;
}
```

> **Full reference**: See `rules/security-patterns.md` Rule 4 for the complete field type → annotation mapping table.

### Rule 8: No Comments in Code

```java
// ✅ CORRECT: Clean code without comments
@PostMapping
public ResponseEntity<?> createProduct(@Valid @RequestBody CreateProductRequest request) {
    CreateProductUseCase.CreateProductInput input = CreateProductUseCase.CreateProductInput.create();
    input.name = request.getName();
    useCase.execute(input);
    return ResponseEntity.accepted().build();
}

// ❌ WRONG: Comments everywhere
// This method creates a new product
@PostMapping
public ResponseEntity<?> createProduct(@Valid @RequestBody CreateProductRequest request) {
    // Create input object
    CreateProductUseCase.CreateProductInput input = CreateProductUseCase.CreateProductInput.create();
    // Set the name field
    input.name = request.getName();
    // Execute the use case
    useCase.execute(input);
    // Return accepted response
    return ResponseEntity.accepted().build();
}
```

### Rule 9: ApiError Response Format

```java
// ✅ CORRECT: Consistent ApiError format
public record ApiError(
    String code,
    String message,
    String traceId
) {}

// Usage:
return ResponseEntity.status(HttpStatus.NOT_FOUND)
    .body(new ApiError(
        "RESOURCE_NOT_FOUND",
        "Product not found: " + id,
        UUID.randomUUID().toString()));
```

### Rule 10: Package Structure

```
{aggregate}/adapter/in/rest/springboot/
├── {CreateAggregate}Controller.java    # Command controller
├── {GetAggregate}Controller.java       # Query controller
├── {UpdateAggregate}Controller.java    # Update controller
└── {DeleteAggregate}Controller.java    # Delete controller

common/adapter/in/rest/springboot/
└── ApiError.java                       # Shared error response
```

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Verification |
|-------|--------------|
| UseCase exists | {UseCase}UseCase.java interface exists |
| UseCase Input exists | {UseCase}UseCase.{UseCase}Input inner class exists |
| Bean configured | {Aggregate}UseCaseConfig.java has @Bean for UseCase |

### Checkpoint 2: Post-Generation

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify constructor injection
grep "Objects.requireNonNull" ${controllerFile}
# Should return matches

# Verify no @Autowired
grep "@Autowired" ${controllerFile}
# Should return empty

# Verify /v1/api prefix
grep "@RequestMapping" ${controllerFile} | grep "/v1/api"
# Should return match

# Verify DTOs are inner classes
grep "public static class.*Request" ${controllerFile}
# Should return match
```

### Checkpoint 3: Runtime Verification

```bash
# Run controller tests
mvn test -Dtest=${ControllerName}Test -q

# Check for bean configuration errors
# Look for "Failed to load ApplicationContext" in output
```

---

## GENERATION TEMPLATES

### Command Controller Template

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.in.rest.springboot;

import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${UseCase}UseCase;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/v1/api/${aggregatePluralLowerCase}")
public class ${UseCase}Controller {

    private final ${UseCase}UseCase ${useCaseCamelCase}UseCase;

    public ${UseCase}Controller(${UseCase}UseCase ${useCaseCamelCase}UseCase) {
        this.${useCaseCamelCase}UseCase = Objects.requireNonNull(${useCaseCamelCase}UseCase);
    }

    @PostMapping
    public ResponseEntity<${UseCase}Response> ${useCaseMethodName}(
            @Valid @RequestBody ${UseCase}Request request) {

        String operationId = UUID.randomUUID().toString();

        ${UseCase}UseCase.${UseCase}Input input = ${UseCase}UseCase.${UseCase}Input.create();
        input.id = request.getId();
        // Map other fields...

        ${useCaseCamelCase}UseCase.execute(input);

        ${UseCase}Response response = new ${UseCase}Response(request.getId(), "ACCEPTED");

        URI location = URI.create("/v1/api/${aggregatePluralLowerCase}/" + request.getId());

        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .location(location)
                .body(response);
    }

    public static class ${UseCase}Request {
        @NotBlank(message = "ID is required")
        @JsonProperty("id")
        private String id;

        @NotBlank(message = "Name is required")
        @Size(max = 255, message = "Name must not exceed 255 characters")
        @JsonProperty("name")
        private String name;

        public ${UseCase}Request() {}

        public String getId() { return id; }
        public void setId(String id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }

    public static class ${UseCase}Response {
        private final String id;
        private final String status;

        public ${UseCase}Response(String id, String status) {
            this.id = id;
            this.status = status;
        }

        public String getId() { return id; }
        public String getStatus() { return status; }
    }
}
```

### Query Controller Template

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.in.rest.springboot;

import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${Query}UseCase;
import ${rootPackage}.common.adapter.in.rest.springboot.ApiError;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/v1/api/${aggregatePluralLowerCase}")
public class ${Query}Controller {

    private final ${Query}UseCase ${queryCamelCase}UseCase;

    public ${Query}Controller(${Query}UseCase ${queryCamelCase}UseCase) {
        this.${queryCamelCase}UseCase = Objects.requireNonNull(${queryCamelCase}UseCase);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> ${queryMethodName}(@PathVariable String id) {
        String traceId = UUID.randomUUID().toString();

        if (id == null || id.trim().isEmpty() || "null".equalsIgnoreCase(id)) {
            return ResponseEntity.badRequest()
                .body(new ApiError("INVALID_ID", "ID cannot be null or empty", traceId));
        }

        try {
            ${Query}UseCase.${Query}Input input = ${Query}UseCase.${Query}Input.create();
            input.${aggregateCamelCase}Id = id;

            var output = ${queryCamelCase}UseCase.execute(input);

            if (output.getExitCode() == ExitCode.SUCCESS) {
                return ResponseEntity.ok(output.get${Aggregate}());
            } else {
                String message = output.getMessage();
                if (message != null && message.toLowerCase().contains("not found")) {
                    return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(new ApiError("RESOURCE_NOT_FOUND", message, traceId));
                }
                return ResponseEntity.badRequest()
                    .body(new ApiError("OPERATION_FAILED", message, traceId));
            }
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ApiError("INTERNAL_ERROR", "Unexpected error", traceId));
        }
    }
}
```

### ApiError Template

```java
package ${rootPackage}.common.adapter.in.rest.springboot;

public record ApiError(
    String code,
    String message,
    String traceId
) {}
```

---

## EXAMPLE OUTPUT

### CreateProductController.java

```java
package tw.teddysoft.aiscrum.product.adapter.in.rest.springboot;

import tw.teddysoft.aiscrum.product.usecase.port.in.CreateProductUseCase;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/v1/api/products")
public class CreateProductController {

    private final CreateProductUseCase createProductUseCase;

    public CreateProductController(CreateProductUseCase createProductUseCase) {
        this.createProductUseCase = Objects.requireNonNull(createProductUseCase);
    }

    @PostMapping
    public ResponseEntity<CreateProductResponse> createProduct(
            @Valid @RequestBody CreateProductRequest request) {

        CreateProductUseCase.CreateProductInput input = CreateProductUseCase.CreateProductInput.create();
        input.productId = request.getProductId();
        input.name = request.getName();
        input.userId = request.getUserId();

        createProductUseCase.execute(input);

        CreateProductResponse response = new CreateProductResponse(
            request.getProductId(), "ACCEPTED");

        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .location(URI.create("/v1/api/products/" + request.getProductId()))
                .body(response);
    }

    public static class CreateProductRequest {
        @NotBlank(message = "Product ID is required")
        @JsonProperty("productId")
        private String productId;

        @NotBlank(message = "Product name is required")
        @JsonProperty("name")
        private String name;

        @NotBlank(message = "User ID is required")
        @JsonProperty("userId")
        private String userId;

        public CreateProductRequest() {}

        public String getProductId() { return productId; }
        public void setProductId(String productId) { this.productId = productId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
    }

    public static class CreateProductResponse {
        private final String productId;
        private final String status;

        public CreateProductResponse(String productId, String status) {
            this.productId = productId;
            this.status = status;
        }

        public String getProductId() { return productId; }
        public String getStatus() { return status; }
    }
}
```

### ApiError.java

```java
package tw.teddysoft.aiscrum.common.adapter.in.rest.springboot;

public record ApiError(
    String code,
    String message,
    String traceId
) {}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.6 (--controller flag): Invoke controller-skill
    ├─ Check: {Aggregate}UseCaseConfig has @Bean for UseCase
    ├─ Input: UseCase interface, controller.yaml
    ├─ Output: {UseCase}Controller.java
    └─ Next: Step 4.6.1 (controller-test.md)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Missing UseCase @Bean | Add @Bean method to {Aggregate}UseCaseConfig |
| @Autowired usage | Replace with constructor injection |
| Missing /v1/api prefix | Add /v1/api to @RequestMapping |
| Separate DTO files | Move to inner classes |
| Business logic in controller | Move to UseCase layer |
| Ignoring UseCase output | Handle output and error conditions |

---
