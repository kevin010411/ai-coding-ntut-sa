# Security Configuration Patterns

> **Authority File** — Centralized CORS and security configuration templates.
> Consumers: `checklist.md`, `deterministic-review-rules.yaml`

---

## CorsConfig.java Template

Centralized CORS configuration bean. Values are derived from `project-config.json`.

```java
package ${rootPackage}.common.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig {

    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/v1/api/**")
                    .allowedOrigins("http://localhost:${frontend.port}")
                    .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
                    .allowedHeaders("*")
                    .allowCredentials(true);
            }
        };
    }
}
```

### Placeholder Values

| Placeholder | Source | Example |
|------------|--------|---------|
| `${rootPackage}` | `project-config.json` → `rootPackage` | `tw.teddysoft.aiscrum` |
| `${frontend.port}` | `project-config.json` → `frontend.port` | `3000` |

### Package Location

```
common/io/springboot/config/
└── CorsConfig.java
```

---

## 3 Critical CORS Rules

### Rule 1: No Wildcard Origins

```java
// CORRECT: Explicit origin
.allowedOrigins("http://localhost:3000")

// WRONG: Wildcard allows any origin
.allowedOrigins("*")  // FORBIDDEN!
```

### Rule 2: Scope to API Path Only

```java
// CORRECT: Scoped to /v1/api/**
registry.addMapping("/v1/api/**")

// WRONG: Global CORS
registry.addMapping("/**")  // TOO BROAD!
```

### Rule 3: No @CrossOrigin on Controllers

```java
// CORRECT: Use centralized CorsConfig (this file)

// WRONG: Per-controller annotation
@CrossOrigin(origins = "http://localhost:3000")  // FORBIDDEN!
@RestController
public class ProductController { }
```

**Gate 2.5**: F-30 enforces Rule 3 automatically.
