# Security Patterns for ezddd-java

> **Authority File** — Canonical security rules for the ezddd-java skill system.
> Consumers: `common-rules.md`, `checklist.md`, `critical-rules.md`, `deterministic-review-rules.yaml`

---

## Rule 1: No Hardcoded Secrets in Java Source

**NEVER** hardcode passwords, API keys, or secrets directly in Java source code.

```java
// CORRECT: Use @Value with environment variable placeholder
@Value("${DB_PASSWORD:}")
private String dbPassword;

// CORRECT: Use Spring Environment
environment.getProperty("spring.datasource.password");

// WRONG: Hardcoded secret in Java
private String password = "mySecret123";       // FORBIDDEN!
private String apiKey = "sk-abc123def456";     // FORBIDDEN!
```

**Gate 2.5**: F-29 (`warn`) — detects `(password|secret|apiKey|api_key)\s*=\s*"[^"$]+` in `*.java`

---

## Rule 2: .gitignore Secret Patterns

`.gitignore` **MUST** include patterns for common secret files:

```gitignore
# Secrets / credentials
.env
.env.*
*.key
*.pem
*.p12
*.jks
credentials.json
service-account.json
```

---

## Rule 3: Properties File Credential Placeholders

Properties files **SHOULD** use Spring placeholder syntax for credentials:

```properties
# CORRECT: Placeholder with safe default
spring.datasource.password=${DB_PASSWORD:root}

# ACCEPTABLE (dev convenience): Hardcoded in test properties
# Gate 2.5 F-28 reports as warn (non-blocking)
spring.datasource.password=root
```

**Gate 2.5**: F-28 (`warn`) — detects `password\s*=\s*[^${\s][^\s]*` in `*.properties`

---

## Rule 4: Request DTO Validation Annotations

All `@RequestBody` parameters **MUST** have `@Valid`. Request DTO fields **SHOULD** have appropriate validation annotations.

### Field Type → Annotation Mapping

| Field Type | Required Annotations | Example |
|-----------|---------------------|---------|
| ID fields (required) | `@NotBlank` | `@NotBlank @JsonProperty("id") private String id;` |
| Name/Title (user input) | `@NotBlank` + `@Size(max = 255)` | `@NotBlank @Size(max = 255) private String name;` |
| Description (free text) | `@Size(max = 2000)` | `@Size(max = 2000) private String description;` |
| Collection fields | `@Size(max = 100)` | `@Size(max = 100) private List<String> tags;` |
| Optional string | `@Size(max = N)` | `@Size(max = 500) private String notes;` |
| Numeric (bounded) | `@Min` / `@Max` | `@Min(0) @Max(1000) private int quantity;` |

```java
// CORRECT: DTO with proper validation
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

**Gate 2.5**: R-15 (`critical`) — requires `@Valid` on every `@RequestBody` parameter

---

## Rule 5: Path Variable Validation

Path variables **MUST** be validated for null, blank, and literal `"null"` string:

```java
@GetMapping("/{id}")
public ResponseEntity<?> getProduct(@PathVariable String id) {
    if (id == null || id.trim().isEmpty() || "null".equalsIgnoreCase(id)) {
        return ResponseEntity.badRequest()
            .body(new ApiError("INVALID_ID", "ID cannot be null or empty", traceId));
    }
    // ...
}
```

> **Cross-reference**: `controller.md` Rule 7 already covers this pattern.

---

## Rule 6: Centralized CORS Configuration

CORS **MUST** be configured via a centralized `CorsConfig` bean. **NEVER** use `@CrossOrigin` on individual controllers.

```java
// CORRECT: Centralized CorsConfig bean
@Configuration
public class CorsConfig {
    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/v1/api/**")
                    .allowedOrigins("http://localhost:3000")
                    .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
                    .allowedHeaders("*")
                    .allowCredentials(true);
            }
        };
    }
}

// WRONG: @CrossOrigin on controller
@CrossOrigin(origins = "http://localhost:3000")  // FORBIDDEN!
@RestController
public class ProductController { }
```

### 3 Critical CORS Rules

1. **No wildcard `*` in `allowedOrigins`** — use explicit origins from `project-config.json` `frontend.port`
2. **Scope to `/v1/api/**` only** — never apply CORS globally
3. **No `@CrossOrigin` on controllers** — centralized config only

**Gate 2.5**: F-30 (`critical`) — detects `@CrossOrigin` on `*Controller.java`

> **Template**: See `patterns/infrastructure/security-config.md` for full CorsConfig template.

---

## Rule 7: CSRF Configuration for Stateless REST APIs

For stateless REST APIs (no session cookies), CSRF protection can be disabled with proper rationale:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
```

**Rationale**: CSRF attacks exploit session cookies. Stateless APIs using Bearer tokens or API keys are not vulnerable to CSRF. If session-based auth is added later, CSRF must be re-enabled.
