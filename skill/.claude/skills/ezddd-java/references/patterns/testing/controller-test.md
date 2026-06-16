---
name: controller-test
description: |
  Controller test generation pattern (Step 4.6.1).
  Generate MockMvc and REST Assured tests for Controllers.

  Referenced by:
  - cbf-workflow.md / swf-workflow.md / idf-workflow.md (Step 4.6.1)
  - Direct user request: "generate tests for [controller]"

  Input: Generated Controller class
  Output:
    - {UseCase}ControllerTest.java (MockMvc unit test)
    - {UseCase}ControllerIntegrationTest.java (REST Assured integration test)

  Both test types MUST pass before code is considered complete.
---

# Controller Test Generation Skill

## Overview

This skill generates comprehensive Controller tests using two testing approaches:
1. **MockMvc Tests** - Fast, isolated unit tests with mocked dependencies
2. **REST Assured Tests** - Integration tests with real HTTP behavior

Both test types MUST be generated and MUST pass.

---

## INPUT

| Source | Path |
|--------|------|
| Controller Class | `src/main/java/{rootPackage}/{aggregate}/adapter/in/rest/springboot/{UseCase}Controller.java` |
| UseCase Interface | `src/main/java/{rootPackage}/{aggregate}/usecase/port/in/{UseCase}UseCase.java` |
| project-config.json | `.dev/project-config.json` |

---

## OUTPUT

| File | Location |
|------|----------|
| MockMvc Test | `src/test/java/{rootPackage}/{aggregate}/adapter/in/rest/springboot/{UseCase}ControllerTest.java` |
| REST Assured Test | `src/test/java/{rootPackage}/{aggregate}/adapter/in/rest/springboot/{UseCase}ControllerIntegrationTest.java` |

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Generate BOTH Test Types (MANDATORY)

```java
// ✅ CORRECT: Two separate test files

// 1. MockMvc Test (unit test, fast)
@WebMvcTest(CreateProductController.class)
public class CreateProductControllerTest { }

// 2. REST Assured Test (integration test)
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
public class CreateProductControllerIntegrationTest { }

// ❌ WRONG: Only one test type
// Missing either MockMvc or REST Assured = INCOMPLETE
```

### Rule 2: No @ActiveProfiles Annotation (ProfileSetter Pattern)

```java
// ✅ CORRECT: No @ActiveProfiles, let TestSuite control profile
@SpringBootTest
@AutoConfigureMockMvc
public abstract class BaseControllerTest {
    // Profile controlled by TestSuite's static block
}

// ✅ TestSuite with ProfileSetter inner class (canonical pattern — see usecase-test.md Rule 9)
// NOTE: Static blocks in @Suite class DON'T execute! Must use @SelectClasses[0] inner class.
@Suite
@SelectClasses({ InMemoryTestSuite.ProfileSetter.class })
@SelectPackages({ "tw.teddysoft.aiscrum" })
@ExcludeClassNamePatterns(".*ControllerTest")
public class InMemoryTestSuite {
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-inmemory");
        }
    }
}

@Suite
@SelectClasses({ OutboxTestSuite.ProfileSetter.class })
@SelectPackages({ "tw.teddysoft.aiscrum" })
@ExcludeClassNamePatterns(".*ControllerTest")
public class OutboxTestSuite {
    public static class ProfileSetter {
        static {
            System.setProperty("spring.profiles.active", "test-outbox");
        }
    }
}

// ❌ WRONG: @ActiveProfiles prevents profile switching
@ActiveProfiles("test-inmemory")  // FORBIDDEN!
public class CreateProductControllerTest { }
```

**Rationale:** @ActiveProfiles prevents dynamic profile switching via TestSuites.

### Rule 3: Use Controller Inner Class for DTOs

```java
// ✅ CORRECT: Reference Controller's inner class
CreateProductController.CreateProductRequest request =
    new CreateProductController.CreateProductRequest();
request.setName("Product Name");
request.setUserId("user-123");

// ❌ WRONG: Assume separate DTO class
CreateProductRequest request = new CreateProductRequest();  // WRONG!
```

### Rule 4: @MockBean for UseCase Dependencies

```java
// ✅ CORRECT: @MockBean for UseCase
@WebMvcTest(CreateProductController.class)
public class CreateProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private CreateProductUseCase useCase;  // Mocked UseCase

    @Autowired
    private ObjectMapper objectMapper;
}

// ❌ WRONG: Manual mock or hardcoded repository
private CreateProductUseCase useCase = mock(CreateProductUseCase.class);  // Wrong context!
private ProductRepository repository = new InMemoryRepository<>();  // FORBIDDEN!
```

### Rule 4.5: doReturn().when() for CqrsOutput<?> Wildcard (MANDATORY)

> **⛔ CRITICAL — COMMON FIRST-GEN COMPILATION FAILURE ⛔**
> `CqrsOutput<?>` 的 wildcard generic 會讓 Mockito 的 `when().thenReturn()` 產生
> capture type 不相容的編譯錯誤。**必須**使用 `doReturn().when()` 繞過泛型檢查。

```java
// ✅ CORRECT: doReturn().when() — 繞過 wildcard capture 問題
doReturn(output).when(useCase).execute(any());

// ❌ WRONG: when().thenReturn() — CqrsOutput<?> capture#1 vs capture#2 編譯失敗
doReturn(output).when(useCase).execute(any());
// Error: no suitable method found for thenReturn(CqrsOutput<capture#1 of ?>)
```

**Note**: `when().thenThrow()` 不受影響（Exception 沒有泛型），可以正常使用。

### Rule 5: Verify /v1/api Prefix in Test Requests

```java
// ✅ CORRECT: /v1/api prefix
mockMvc.perform(post("/v1/api/products")
    .contentType(MediaType.APPLICATION_JSON)
    .content(requestJson))

// ❌ WRONG: Missing /v1/api prefix
mockMvc.perform(post("/products")  // WRONG!
    .contentType(MediaType.APPLICATION_JSON)
    .content(requestJson))
```

### Rule 6: Test HTTP Status Codes Correctly

```java
// ✅ CORRECT: Status codes per operation type

// Command (async) - 202 ACCEPTED
@Test
void should_return_202_when_create_succeeds() throws Exception {
    doReturn(successOutput()).when(useCase).execute(any());

    mockMvc.perform(post("/v1/api/products")
            .contentType(MediaType.APPLICATION_JSON)
            .content(requestJson))
        .andExpect(status().isAccepted());  // 202
}

// Query - 200 OK
@Test
void should_return_200_when_get_succeeds() throws Exception {
    mockMvc.perform(get("/v1/api/products/{id}", productId))
        .andExpect(status().isOk());  // 200
}

// Not found - 404
@Test
void should_return_404_when_not_found() throws Exception {
    doReturn(notFoundOutput()).when(useCase).execute(any());

    mockMvc.perform(get("/v1/api/products/{id}", productId))
        .andExpect(status().isNotFound());  // 404
}

// Validation error - 400
@Test
void should_return_400_when_validation_fails() throws Exception {
    mockMvc.perform(post("/v1/api/products")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))  // Missing required fields
        .andExpect(status().isBadRequest());  // 400
}
```

### Rule 7: Test Execution and Verification

```bash
# ✅ CORRECT: Execute and verify BOTH test types

# Step 1: Run MockMvc tests
mvn test -Dtest=CreateProductControllerTest -q

# Step 2: Run REST Assured tests
mvn test -Dtest=CreateProductControllerIntegrationTest -q

# ⛔ BOTH must show BUILD SUCCESS
# ⛔ If ANY test fails, FIX before proceeding
```

**Success indicators:**
- `BUILD SUCCESS`
- `Tests run: X, Failures: 0, Errors: 0`

**Failure indicators (MUST FIX):**
- `BUILD FAILURE`
- `Failures: X` (X > 0)
- `NoSuchBeanDefinitionException`
- `Failed to load ApplicationContext`

### Rule 8: REST Assured Setup Pattern

```java
// ✅ CORRECT: REST Assured integration test structure
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@TestPropertySource(properties = "aiscrum.test-data.enabled=false")
public class CreateProductControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @MockBean
    private CreateProductUseCase useCase;

    @BeforeEach
    void setup() {
        RestAssured.port = port;
        RestAssured.basePath = "/v1/api";  // Include /v1/api
    }

    @Test
    void should_create_product() {
        doReturn(successOutput()).when(useCase).execute(any());

        given()
            .contentType(ContentType.JSON)
            .body(requestJson)
        .when()
            .post("/products")
        .then()
            .statusCode(202)
            .body("productId", notNullValue());
    }
}
```

### Rule 9: Test Naming Convention

```java
// ✅ CORRECT: should_[result]_when_[condition]
@Test
void should_return_product_when_exists() { }

@Test
void should_return_404_when_product_not_found() { }

@Test
void should_return_400_when_id_is_null() { }

// ❌ WRONG: Vague or inconsistent names
@Test
void testGetProduct() { }

@Test
void test1() { }
```

### Rule 10: Minimum Test Coverage

```java
// ✅ CORRECT: All required scenarios covered

@Nested
@DisplayName("Success Cases")
class SuccessCases {
    @Test void should_return_202_when_create_succeeds() { }
    @Test void should_return_200_when_get_succeeds() { }
}

@Nested
@DisplayName("Validation Cases")
class ValidationCases {
    @Test void should_return_400_when_required_fields_missing() { }
    @Test void should_return_400_when_id_is_null() { }
}

@Nested
@DisplayName("Error Cases")
class ErrorCases {
    @Test void should_return_404_when_not_found() { }
    @Test void should_return_500_when_unexpected_error() { }
}
```

| Category | Required Tests |
|----------|----------------|
| Success | 200/201/202 for each operation |
| Validation | 400 for invalid input |
| Business Error | 404 for not found, 409 for conflict |
| Exception | 500 for unexpected errors |

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Pre-Generation

| Check | Verification |
|-------|--------------|
| Controller exists | {UseCase}Controller.java exists |
| Controller compiles | No compilation errors |

### Checkpoint 2: Post-Generation

```bash
# Verify both test files created
ls -la src/test/java/{package}/{aggregate}/adapter/in/rest/springboot/
# Should see: {UseCase}ControllerTest.java
# Should see: {UseCase}ControllerIntegrationTest.java

# Verify no @ActiveProfiles
grep "@ActiveProfiles" ${testFile}
# Should return empty

# Verify /v1/api prefix used
grep "/v1/api" ${testFile}
# Should return matches
```

### Checkpoint 3: Test Execution (MANDATORY)

```bash
# Run MockMvc tests
mvn test -Dtest=${UseCase}ControllerTest -q
# MUST show BUILD SUCCESS

# Run REST Assured tests
mvn test -Dtest=${UseCase}ControllerIntegrationTest -q
# MUST show BUILD SUCCESS

# Run dual-profile tests (if applicable)
SPRING_PROFILES_ACTIVE=test-inmemory mvn test -Dtest=${UseCase}ControllerTest -q
SPRING_PROFILES_ACTIVE=test-outbox mvn test -Dtest=${UseCase}ControllerTest -q
```

---

## GENERATION TEMPLATES

### MockMvc Test Template

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.in.rest.springboot;

import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${UseCase}UseCase;
import ${rootPackage}.common.adapter.in.rest.springboot.ApiError;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(${UseCase}Controller.class)
public class ${UseCase}ControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ${UseCase}UseCase useCase;

    @Autowired
    private ObjectMapper objectMapper;

    @Nested
    @DisplayName("Success Cases")
    class SuccessCases {

        @Test
        void should_return_202_when_${useCaseMethodName}_succeeds() throws Exception {
            // Given
            ${UseCase}Controller.${UseCase}Request request =
                new ${UseCase}Controller.${UseCase}Request();
            request.setId("test-id");

            ${UseCase}UseCase.${UseCase}Output output =
                ${UseCase}UseCase.${UseCase}Output.create();
            output.setExitCode(ExitCode.SUCCESS);

            doReturn(output).when(useCase).execute(any());

            // When & Then
            mockMvc.perform(post("/v1/api/${aggregatePluralLowerCase}")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isAccepted())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").exists());
        }
    }

    @Nested
    @DisplayName("Validation Cases")
    class ValidationCases {

        @Test
        void should_return_400_when_required_fields_missing() throws Exception {
            // Given - empty request
            String emptyJson = "{}";

            // When & Then
            mockMvc.perform(post("/v1/api/${aggregatePluralLowerCase}")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(emptyJson))
                .andExpect(status().isBadRequest());
        }
    }

    @Nested
    @DisplayName("Error Cases")
    class ErrorCases {

        @Test
        void should_return_500_when_unexpected_error() throws Exception {
            // Given
            ${UseCase}Controller.${UseCase}Request request =
                new ${UseCase}Controller.${UseCase}Request();
            request.setId("test-id");

            when(useCase.execute(any())).thenThrow(new RuntimeException("Unexpected"));

            // When & Then
            mockMvc.perform(post("/v1/api/${aggregatePluralLowerCase}")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"));
        }
    }
}
```

### REST Assured Integration Test Template

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.in.rest.springboot;

import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${UseCase}UseCase;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.TestPropertySource;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestPropertySource(properties = "aiscrum.test-data.enabled=false")
public class ${UseCase}ControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @MockBean
    private ${UseCase}UseCase useCase;

    @BeforeEach
    void setup() {
        RestAssured.port = port;
        RestAssured.basePath = "/v1/api";
    }

    @Nested
    @DisplayName("Success Cases")
    class SuccessCases {

        @Test
        void should_return_202_when_${useCaseMethodName}_succeeds() {
            // Given
            ${UseCase}UseCase.${UseCase}Output output =
                ${UseCase}UseCase.${UseCase}Output.create();
            output.setExitCode(ExitCode.SUCCESS);

            doReturn(output).when(useCase).execute(any());

            String requestBody = """
                {
                    "id": "test-id"
                }
                """;

            // When & Then
            given()
                .contentType(ContentType.JSON)
                .body(requestBody)
            .when()
                .post("/${aggregatePluralLowerCase}")
            .then()
                .statusCode(202)
                .header("Location", notNullValue())
                .body("id", notNullValue());
        }
    }

    @Nested
    @DisplayName("Validation Cases")
    class ValidationCases {

        @Test
        void should_return_400_when_required_fields_missing() {
            given()
                .contentType(ContentType.JSON)
                .body("{}")
            .when()
                .post("/${aggregatePluralLowerCase}")
            .then()
                .statusCode(400);
        }
    }

    @Nested
    @DisplayName("Error Cases")
    class ErrorCases {

        @Test
        void should_return_500_when_unexpected_error() {
            when(useCase.execute(any())).thenThrow(new RuntimeException("Unexpected"));

            String requestBody = """
                {
                    "id": "test-id"
                }
                """;

            given()
                .contentType(ContentType.JSON)
                .body(requestBody)
            .when()
                .post("/${aggregatePluralLowerCase}")
            .then()
                .statusCode(500)
                .body("code", equalTo("INTERNAL_ERROR"));
        }
    }
}
```

---

## EXAMPLE OUTPUT

### CreateProductControllerTest.java (MockMvc)

```java
package tw.teddysoft.aiscrum.product.adapter.in.rest.springboot;

import tw.teddysoft.aiscrum.product.usecase.port.in.CreateProductUseCase;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CreateProductController.class)
public class CreateProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private CreateProductUseCase useCase;

    @Autowired
    private ObjectMapper objectMapper;

    @Nested
    @DisplayName("Success Cases")
    class SuccessCases {

        @Test
        void should_return_202_when_create_succeeds() throws Exception {
            CreateProductController.CreateProductRequest request =
                new CreateProductController.CreateProductRequest();
            request.setProductId("prod-123");
            request.setName("Test Product");
            request.setUserId("user-1");

            CreateProductUseCase.CreateProductOutput output =
                CreateProductUseCase.CreateProductOutput.create();
            output.setExitCode(ExitCode.SUCCESS);

            doReturn(output).when(useCase).execute(any());

            mockMvc.perform(post("/v1/api/products")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isAccepted())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.productId").value("prod-123"));
        }
    }

    @Nested
    @DisplayName("Validation Cases")
    class ValidationCases {

        @Test
        void should_return_400_when_required_fields_missing() throws Exception {
            mockMvc.perform(post("/v1/api/products")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{}"))
                .andExpect(status().isBadRequest());
        }
    }
}
```

### CreateProductControllerIntegrationTest.java (REST Assured)

```java
package tw.teddysoft.aiscrum.product.adapter.in.rest.springboot;

import tw.teddysoft.aiscrum.product.usecase.port.in.CreateProductUseCase;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.TestPropertySource;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestPropertySource(properties = "aiscrum.test-data.enabled=false")
public class CreateProductControllerIntegrationTest {

    @LocalServerPort
    private int port;

    @MockBean
    private CreateProductUseCase useCase;

    @BeforeEach
    void setup() {
        RestAssured.port = port;
        RestAssured.basePath = "/v1/api";
    }

    @Nested
    @DisplayName("Success Cases")
    class SuccessCases {

        @Test
        void should_return_202_when_create_succeeds() {
            CreateProductUseCase.CreateProductOutput output =
                CreateProductUseCase.CreateProductOutput.create();
            output.setExitCode(ExitCode.SUCCESS);

            doReturn(output).when(useCase).execute(any());

            given()
                .contentType(ContentType.JSON)
                .body("""
                    {
                        "productId": "prod-123",
                        "name": "Test Product",
                        "userId": "user-1"
                    }
                    """)
            .when()
                .post("/products")
            .then()
                .statusCode(202)
                .header("Location", notNullValue())
                .body("productId", equalTo("prod-123"));
        }
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

```
code executor
    ↓
    Step 4.6.1: Generate controller tests (this file)
    ├─ Input: {UseCase}Controller.java
    ├─ Output: {UseCase}ControllerTest.java, {UseCase}ControllerIntegrationTest.java
    ├─ Verify: BOTH test types pass
    └─ Next: Code Review (Step 10)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| NoSuchBeanDefinitionException | Add @MockBean for missing UseCase |
| Failed to load ApplicationContext | Check Spring configuration |
| @ActiveProfiles present | Remove and use ProfileSetter pattern |
| Missing /v1/api prefix | Add /v1/api to request paths |
| Only one test type generated | Generate the missing test type |
| Test failures | Fix and re-run until all pass |

---
