# Query Use Case Generation Skill

## Overview

This skill generates Query Use Case components following CQRS read-side patterns:
- **UseCase Interface** - Port layer (inbound port)
- **Service Implementation** - Application service layer
- **Projection/outport dependency** - Load read-side state without violating Clean Architecture boundaries
- **Read-only Entity** - Query result model

Queries are **read-only** operations that never modify system state.

### Read-only Entity Rule

Generate query results around read-only entities when they preserve Clean Architecture boundaries; otherwise use DTO fallback at the outport boundary.

- Return `ProductReadOnly`, `List<ProductReadOnly>`, or the spec-declared read-only entity type from the custom `CqrsOutput<T>` subclass.
- Load read-side state through a CA-safe projection/outport, then convert it to a read-only response or DTO fallback before setting output.
- Do not generate DTO records, DTO projections, or `toDto(...)` mapper methods for query results unless the Clean Architecture boundary rule requires DTO fallback for the outport.
- Do not expose the original mutable aggregate or child entity. A mutable entity leak is still forbidden.
- Convert nested returned entities into read-only entities.
- Return immutable collections for entity lists and nested entity collections.

### Clean Architecture Boundary Rule for Read-only Outputs

Read-only output is allowed only when it preserves Clean Architecture dependency direction. Before generating a read-only entity, evaluate the boundary it crosses:

- A usecase outport (`port/out/projection`, `port/out/inquiry`, repository-like port) must not expose adapter/infrastructure types, JPA persistent objects, Spring Data projections, or domain entities whose implementation would force an outer layer concern into the domain/application layer.
- A `*ReadOnly` type must not require the mutable domain model to depend on usecase, adapter, projection, DTO, or persistence packages. Shared interfaces for proxy-style read-only views are valid only when the interface belongs to the domain model boundary and contains domain-safe query operations.
- Inheritance-style read-only entities are valid only when extending the domain model does not introduce usecase/adapter dependencies or leak mutable state/commands across the port boundary.
- If a read-only approach would violate these CA layer rules, do not force read-only through the outport. Use a DTO/read-model record at the outport boundary to compensate, then map inside the application layer to the safest response model.
- The fallback DTO belongs in the usecase/application boundary (for example `{aggregate}/usecase/port/` or a dedicated DTO/readmodel package under `usecase/port`), not in adapter/infrastructure. Adapter implementations may map persistence data to that DTO before returning through the outport.
- When DTO fallback is selected, the Query `CqrsOutput<T>` wraps the DTO or immutable list of DTOs. Do not call it a read-only entity, and do not generate read-only proxy/inheritance code for that query.

Decision order:
1. Prefer spec-declared read-only entities only if the domain/application dependency direction remains clean.
2. If read-only would make an outport depend on the wrong layer or pull outer-layer details inward, use DTO fallback for the outport.
3. Never expose mutable aggregate/entity instances as a shortcut.

### Read-only Entity Implementation Approaches

Every read-only entity must use one of these two implementation approaches:

1. **Proxy / composition approach**
   - The read-only entity wraps the original domain model object.
   - The read-only entity and the original domain model class must share a common interface that declares the allowed query operations.
   - The proxy implements that shared interface, delegates query operations to the wrapped domain model object, and rejects or omits state-changing command operations.
   - Never expose the wrapped mutable domain model object through a getter.

2. **Inheritance approach**
   - The read-only entity class must extend the original domain model class.
   - Override every state-changing command method to throw `UnsupportedOperationException` or an equivalent domain protection exception.
   - Override query methods that return entities or entity collections so they return read-only entities and immutable collections.

```java
class GetProductOutput extends CqrsOutput<GetProductOutput> {
    private ProductReadOnly product;
    public ProductReadOnly getProduct() { return product; }
    public GetProductOutput setProduct(ProductReadOnly product) { this.product = product; return this; }
}

class GetProductsOutput extends CqrsOutput<GetProductsOutput> {
    private List<ProductReadOnly> products = List.of();
    public List<ProductReadOnly> getProducts() { return products; }
    public GetProductsOutput setProducts(List<ProductReadOnly> products) {
        this.products = List.copyOf(products);
        return this;
    }
}
```

---

## INPUT

| Source | Path |
|--------|------|
| IDF Frame | `JSON spec` |
| Use Case Spec | `JSON spec `useCase`` |

---

## OUTPUT

| File | Location |
|------|----------|
| UseCase Interface | `src/main/java/{rootPackage}/{aggregate}/usecase/port/in/{UseCase}UseCase.java` |
| Service Implementation | `src/main/java/{rootPackage}/{aggregate}/usecase/service/{UseCase}Service.java` |
| Read-only Entity | `src/main/java/{rootPackage}/{aggregate}/entity/{Name}ReadOnly.java` |
| DTO fallback for CA-safe outport | `src/main/java/{rootPackage}/{aggregate}/usecase/port/{Name}Dto.java` or `{Name}ReadModel.java` |

---

## QUERY CATEGORIES

### Category 1: Single Item Query (Get by ID)

**Returns a single read-only entity wrapped in CqrsOutput.**

```java
// UseCase Interface — Output must extend CqrsOutput<T> (CRTP, see Rule 11)
public interface GetProductUseCase extends Query<GetProductUseCase.GetProductInput, GetProductUseCase.GetProductOutput> {
    class GetProductInput implements Input {
        public String productId;
        public static GetProductInput create() { return new GetProductInput(); }
    }

    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private ProductReadOnly product;
        public ProductReadOnly getProduct() { return product; }
        public GetProductOutput setProduct(ProductReadOnly product) { this.product = product; return this; }
    }
}

// Service
public class GetProductService implements GetProductUseCase {
    private final ProductRepository productRepository;

    @Override
    public GetProductOutput execute(GetProductInput input) {
        requireNotNull("Input", input);
        requireNotNull("Product id", input.productId);

        Product product = productRepository.findById(ProductId.of(input.productId))
                .orElseThrow(() -> new IllegalArgumentException("Product not found"));
        ProductReadOnly productReadOnly = ProductReadOnly.from(product);
        return new GetProductOutput()
                .setProduct(productReadOnly)
                .setId(input.productId)
                .succeed();
    }
}
```

### Category 2: List Query (Get All/Filtered)

**Returns an immutable list of read-only entities.**

```java
// UseCase Interface
public interface GetProductsUseCase extends Query<GetProductsUseCase.GetProductsInput, GetProductsUseCase.GetProductsOutput> {
    class GetProductsInput implements Input {
        public String userId;
        public String sortBy;
        public static GetProductsInput create() { return new GetProductsInput(); }
    }

    class GetProductsOutput extends CqrsOutput<GetProductsOutput> {
        private List<ProductReadOnly> products = List.of();
        public List<ProductReadOnly> getProducts() { return products; }
        public static GetProductsOutput create() { return new GetProductsOutput(); }
        public GetProductsOutput setProducts(List<ProductReadOnly> products) {
            this.products = List.copyOf(products);
            return this;
        }
    }
}

// Service
public class GetProductsService implements GetProductsUseCase {
    private final ProductRepository productRepository;

    @Override
    public GetProductsOutput execute(GetProductsInput input) {
        List<ProductReadOnly> products = productRepository.findAll().stream()
                .map(ProductReadOnly::from)
                .toList();

        return GetProductsOutput.create()
            .setProducts(products)
            .setExitCode(ExitCode.SUCCESS);
    }
}
```

### Category 3: Filtered Query with Date/Criteria

**Returns filtered results wrapped in CqrsOutput.**

```java
// UseCase Interface — Output must extend CqrsOutput<T> (CRTP, see Rule 11)
public interface GetTasksByDateUseCase extends Query<GetTasksByDateUseCase.GetTasksByDateInput, GetTasksByDateUseCase.GetTasksByDateOutput> {
    class GetTasksByDateInput implements Input {
        public String userId;
        public LocalDate date;
        public static GetTasksByDateInput create() { return new GetTasksByDateInput(); }
    }

    class GetTasksByDateOutput extends CqrsOutput<GetTasksByDateOutput> {
        private List<TaskReadOnly> tasks;
        public List<TaskReadOnly> getTasks() { return tasks; }
        public GetTasksByDateOutput setTasks(List<TaskReadOnly> tasks) { this.tasks = tasks; return this; }
    }
}

// Service
public class GetTasksByDateService implements GetTasksByDateUseCase {
    private final TasksByDateProjection projection;

    @Override
    public GetTasksByDateOutput execute(GetTasksByDateInput input) {
        requireNotNull("Input", input);
        requireNotNull("Date", input.date);

        var projectionInput = new TasksByDateProjection.TasksByDateInput();
        projectionInput.userId = input.userId;
        projectionInput.date = input.date;

        List<TaskReadOnly> tasks = projection.query(projectionInput);
        return new GetTasksByDateOutput()
                .setTasks(tasks)
                .succeed();
    }
}
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: Query Interface Structure

```java
// ✅ CORRECT: Output extends CqrsOutput with CRTP self-reference (see Rule 11)
public interface GetProductUseCase extends Query<GetProductUseCase.GetProductInput, GetProductUseCase.GetProductOutput> {
    class GetProductInput implements Input {
        public String productId;
        public static GetProductInput create() { return new GetProductInput(); }
    }

    class GetProductOutput extends CqrsOutput<GetProductOutput> {  // CRTP!
        private ProductReadOnly product;
        public ProductReadOnly getProductReadOnly() { return product; }
        public GetProductOutput setProductReadOnly(ProductReadOnly dto) { this.product = dto; return this; }
    }
}

// ✅ CORRECT: List query — also uses CqrsOutput CRTP
public interface GetProductsUseCase extends Query<GetProductsUseCase.GetProductsInput, GetProductsUseCase.GetProductsOutput> {
    class GetProductsOutput extends CqrsOutput<GetProductsOutput> {  // CRTP!
        public List<ProductReadOnly> products;
    }
}

// ❌ WRONG: Bare DTO without CqrsOutput wrapper
public interface GetProductUseCase extends Query<GetProductInput, ProductReadOnly> { }  // Compilation error!

// ❌ WRONG: Extending Command (queries should extend Query)
public interface GetProductUseCase extends Command<...> { }
```

**Rationale:** `Query<I, O>` requires `O extends CqrsOutput<O>` (CRTP). Use inner Output class to wrap DTOs.

### Rule 2: Use Projection, NOT Repository

```java
// ✅ CORRECT: Inject Projection for queries
public class GetProductService implements GetProductUseCase {
    private final ProductProjection projection;  // Projection for read

    public GetProductService(ProductProjection projection) {
        this.projection = projection;
    }
}

// ❌ WRONG: Using Repository for queries
public class GetProductService implements GetProductUseCase {
    private final Repository<Product, ProductId> repository;  // WRONG!
}
```

**Rationale:** CQRS separates read (Projection) from write (Repository).

### Rule 3: Projection Uses query() Method

```java
// ✅ CORRECT: Use query() method for Projection
List<ProductReadOnly> products = projection.query(input);

// For simple single-item lookup (custom method)
ProductReadOnly product = projection.findById(productId);

// ❌ WRONG: Using execute() on Projection
List<ProductReadOnly> products = projection.execute(input);  // WRONG method name!
```

**Rationale:** `query()` is the standard method defined by `Projection<I, O>` interface.

### Rule 4: Never Modify State in Queries

```java
// ✅ CORRECT: Read-only query
@Override
public ProductReadOnly execute(GetProductInput input) {
    return projection.findById(input.productId);  // Read only
}

// ❌ WRONG: Modifying state in query
@Override
public ProductReadOnly execute(GetProductInput input) {
    Product product = repository.findById(...).orElseThrow();
    product.incrementViewCount();  // FORBIDDEN! State modification
    repository.save(product);      // FORBIDDEN! Writing in query
    return ProductReadOnly.from(product);
}
```

**Rationale:** Queries must be side-effect free for CQRS compliance.

### Rule 5: Return Read-only Entity (wrapped in CqrsOutput), NOT Mutable Domain Entity

```java
// ✅ CORRECT: DTO wrapped in CqrsOutput Output class (default query pattern)
public interface GetProductUseCase extends Query<..., GetProductUseCase.GetProductOutput> {
    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private ProductReadOnly product;  // DTO inside CqrsOutput wrapper
    }
}

// ✅ CORRECT: Read-only entity wrapped in CqrsOutput when spec declares readOnlyEntities
public interface GetProductUseCase extends Query<..., GetProductUseCase.GetProductOutput> {
    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private ProductReadOnly product;  // Read-only entity view, not mutable Product
    }
}

// ✅ CORRECT: Projection returns bare DTO (Projection is not constrained by CqrsOutput)
public interface ProductProjection extends Projection<..., ProductReadOnly> {
    ProductReadOnly findById(String productId);
}

// ❌ WRONG: Returning mutable domain entity
public interface GetProductUseCase extends Query<..., Product> {  // Mutable entity leak!
}

// ❌ WRONG: Bare DTO as Query output (violates CqrsOutput constraint)
public interface GetProductUseCase extends Query<..., ProductReadOnly> {  // Compilation error!
}
```

**Rationale:** Mutable domain entities must not leak outside the aggregate boundary. Query Output must extend `CqrsOutput<T>` (CRTP). DTO is the default read model; a spec-declared read-only entity is allowed when it blocks mutation, wraps nested entities, and uses immutable collections.

### Rule 6: No @Service or @Repository Annotations

> **Shared Rule** — See `references/rules/usecase-patterns.md` § No @Service or @Component Annotation

Additionally for Query: JPA Projection interfaces must NOT use `@Repository` — Spring Data JPA auto-implements the interface.

### Rule 7: Projection Interface Structure

```java
// ✅ CORRECT: Projection interface in port/out/projection
package tw.teddysoft.aiscrum.product.usecase.port.out.projection;

public interface ProductsProjection extends Projection<ProductsProjection.Input, List<ProductReadOnly>> {

    class Input implements ProjectionInput {
        public String userId;
        public SortBy sortBy = SortBy.NAME;
        public SortOrder sortOrder = SortOrder.ASC;
    }

    enum SortBy { NAME, CREATED_DATE }
    enum SortOrder { ASC, DESC }
}

// ❌ WRONG: Projection in adapter layer
package tw.teddysoft.aiscrum.product.adapter.out.projection;  // Should be in port/out/
```

**Rationale:** Projection interface is a port (contract), implementations are adapters.

### Rule 8: JPA Projection Implementation

```java
// ✅ CORRECT: JPA Projection extends both Projection and JpaRepository
package tw.teddysoft.aiscrum.product.adapter.out.database.springboot.projection;

public interface JpaProductsProjection extends ProductsProjection, JpaRepository<ProductData, String> {

    @Override
    default List<ProductReadOnly> query(Input input) {
        Sort sort = Sort.by(
            input.sortOrder == SortOrder.ASC ? Sort.Direction.ASC : Sort.Direction.DESC,
            input.sortBy == SortBy.NAME ? "name" : "createdAt"
        );
        List<ProductData> data = findByUserIdAndIsDeletedFalse(input.userId, sort);
        return ProductMapper.toReadOnly(data);
    }

    // Spring Data JPA query method
    List<ProductData> findByUserIdAndIsDeletedFalse(String userId, Sort sort);
}
```

**Rationale:** JPA Projection combines the port interface with Spring Data JPA capabilities.

### Rule 8.5: Query Services 不需要 Blanket Catch

> **Design Intent**: Query 是 read-only 操作，不產生業務副作用。
> 與 Command 的 blanket catch 模式（`try { ... } catch (Exception e) { throw new UseCaseFailureException(e); }`）不同，
> Query 只需 `requireNotNull` precondition 驗證 + 直接呼叫 Projection。
> 如果 Projection 出錯（如 DB timeout），例外自然向上傳播，不需包裝。
>
> Command 的 blanket catch 規則見 `patterns/usecase/command.md` Rule 8.5 / Rule 9。

### Rule 9: DTO as Record

```java
// ✅ CORRECT: DTO as immutable record
package tw.teddysoft.aiscrum.product.usecase.port;

public record ProductReadOnly(
    String productId,
    String name,
    String description,
    boolean isDeleted
) {
    // Factory method for mapping
    public static ProductReadOnly from(ProductData data) {
        return new ProductReadOnly(
            data.getId(),
            data.getName(),
            data.getDescription(),
            data.isDeleted()
        );
    }
}

// ❌ WRONG: Mutable DTO class with setters
public class ProductReadOnly {
    private String productId;
    public void setProductId(String id) { this.productId = id; }  // Avoid
}
```

**Rationale:** DTOs should be immutable for thread-safety and clarity.

### Rule 10: Package Locations

> **Shared Rule** — See `references/rules/usecase-patterns.md` § Package Location Rules

### Rule 10.5: CqrsOutput API — succeed()/fail() 與 setExitCode() 等價

> `.setExitCode(ExitCode.SUCCESS)` 等同於 `.succeed()`；`.setExitCode(ExitCode.FAILURE)` 等同於 `.fail()`。
> 本文件範例混用兩種風格皆合法。Canonical 定義見 `patterns/usecase/command.md` Rule 8。

### Rule 11: CqrsOutput CRTP Pattern (Self-Referencing Generic)

> **⚠️ CRITICAL**: `CqrsOutput` 使用 CRTP（Curiously Recurring Template Pattern）自引用泛型：
> `CqrsOutput<T extends CqrsOutput<T>>`。當 Query 的 Output 需要繼承 `CqrsOutput` 時，
> 必須使用完整的 CRTP 自引用語法。

```java
// ✅ CORRECT: CRTP self-reference — GetProductOutput references itself
public interface GetProductUseCase
        extends Query<GetProductUseCase.GetProductInput, GetProductUseCase.GetProductOutput> {

    class GetProductInput implements Input {
        public String productId;
        public static GetProductInput create() { return new GetProductInput(); }
    }

    // Output wraps DTO inside CqrsOutput with CRTP self-reference
    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private ProductReadOnly product;

        public ProductReadOnly getProductReadOnly() { return product; }
        public GetProductOutput setProductReadOnly(ProductReadOnly dto) {
            this.product = dto;
            return this;
        }
    }
}

// ❌ WRONG: Raw CqrsOutput without CRTP type parameter
class GetProductOutput extends CqrsOutput {  // Missing <GetProductOutput>!
    // Compilation warning + fluent methods return wrong type
}

// ❌ WRONG: Returning bare DTO when framework requires CqrsOutput subtype
public interface GetProductUseCase extends Query<GetProductInput, ProductReadOnly> {
    // Compilation error: ProductReadOnly doesn't extend CqrsOutput
}

// ❌ WRONG: Using Optional as return type
public interface GetProductUseCase extends Query<GetProductInput, Optional<ProductReadOnly>> {
    // Compilation error: Optional doesn't extend CqrsOutput
}
```

**Why CRTP?** `CqrsOutput<T>` 的 fluent setter 方法（如 `setId()`, `succeed()`, `setExitCode()`）
回傳 `T` 而非 `CqrsOutput`，讓呼叫者不需要強制轉型：

```java
// With CRTP: fluent methods return the concrete type
GetProductOutput output = new GetProductOutput()
    .setProductReadOnly(dto)        // returns GetProductOutput
    .setId(productId)          // returns GetProductOutput (from CqrsOutput<GetProductOutput>)
    .succeed();                // returns GetProductOutput

// Without CRTP: need manual cast
CqrsOutput output = new GetProductOutput()
    .setId(productId)          // returns raw CqrsOutput
    .succeed();                // returns raw CqrsOutput — lost GetProductOutput type!
```

### Rule 12: Projection Bean Must Be Profile-Aware ⭐⭐⭐ CRITICAL

> **⚠️ CRITICAL**: Projection beans 必須註冊在 **profile-specific** config 中。
> **絕對不可**放在 profile-neutral 的 `UseCaseConfig`！
>
> InMemory profile 的 Projection 注入 `Map<String, Data>` data store。
> Outbox profile 的 Projection 注入 `OrmClient`（JPA CrudRepository）。
> 放在 `UseCaseConfig` 會導致 Outbox profile 找不到 Map bean → 啟動失敗。

```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️ InMemoryOrmDb 不提供 findAll()！                           ║
╠════════════════════════════════════════════════════════════════╣
║  InMemoryOrmDb 的 API 只有 save/findById/delete，無 findAll。 ║
║  IDF Projection 需要遍歷所有資料，必須透過共享 Map 存取。       ║
║                                                                ║
║  解法：建立 shared ConcurrentHashMap bean，注入到 InMemoryOrmDb ║
║  constructor 和 Projection bean。                              ║
╚════════════════════════════════════════════════════════════════╝
```

```java
// ✅ CORRECT: InMemory Projection — 使用 shared ConcurrentHashMap
@Configuration
@Profile({"inmemory", "test-inmemory"})
public class PbiInMemoryRepositoryConfig {

    // Step 1: Create shared data store (ConcurrentHashMap)
    @Bean
    public Map<String, ProductBacklogItemData> pbiDataStore() {
        return new ConcurrentHashMap<>();
    }

    // Step 2: InMemoryOrmDb uses the shared map
    @Bean
    public InMemoryOrmDb<ProductBacklogItemData> pbiOrmDb(
            Map<String, ProductBacklogItemData> pbiDataStore) {
        return new InMemoryOrmDb<>(pbiDataStore);
    }

    // Step 3: Repository bean uses InMemoryOrmDb (unchanged)
    // ... repository bean ...

    // Step 4: Projection bean iterates the shared map directly
    @Bean
    public PbisByProductProjection pbisByProductProjection(
            Map<String, ProductBacklogItemData> pbiDataStore) {
        return input -> pbiDataStore.values().stream()
                .filter(d -> d.getProductId().equals(input.productId))
                .map(ProductBacklogItemMapper::toReadOnly)
                .collect(Collectors.toList());
    }
}

// ✅ CORRECT: Outbox Projection — 在 OutboxRepositoryConfig 中註冊
@Configuration
@Profile({"outbox", "test-outbox"})
public class PbiOutboxRepositoryConfig {

    // Outbox Projection uses OrmClient.findAll() (CrudRepository)
    @Bean
    public PbisByProductProjection pbisByProductProjection(
            ProductBacklogItemOrmClient ormClient) {
        return input -> StreamSupport.stream(ormClient.findAll().spliterator(), false)
                .filter(d -> d.getProductId().equals(input.productId))
                .map(ProductBacklogItemMapper::toReadOnly)
                .collect(Collectors.toList());
    }
}

// ❌ WRONG: Projection 在 profile-neutral UseCaseConfig — Outbox 啟動失敗！
@Configuration  // 沒有 @Profile！
public class PbiUseCaseConfig {
    @Bean
    public PbisByProductProjection projection(
            Map<String, ProductBacklogItemData> dataStore) {  // Outbox 沒有此 bean!
        return input -> dataStore.values().stream()...;
    }
}

// ❌ WRONG: InMemoryOrmDb without shared map — Projection 無法存取資料！
@Bean
public InMemoryOrmDb<PbiData> ormDb() {
    return new InMemoryOrmDb<>();  // No shared map → Projection can't iterate!
}
```

> **Note**: `CrudRepository.findAll()` 回傳 `Iterable`，不是 `List`。
> 必須用 `StreamSupport.stream(iterable.spliterator(), false)` 轉換。

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Input Validation

Before generating code, verify:

| Check | Command | Expected |
|-------|---------|----------|
| use-case.yaml exists | `test -f ${usecaseYamlPath}` | File exists |
| Has query type | `grep "type: query" ${usecaseYamlPath}` | Found |
| Has display fields | `grep "output:" ${usecaseYamlPath}` | Found |

```
IF ANY CHECK FAILS:
  Report error: "Invalid use-case.yaml: missing required field"
  STOP - do not proceed
```

### Checkpoint 2: Pre-Generation Verification

Before writing any file:

| Check | Verification |
|-------|--------------|
| Extends Query | Interface extends `Query<Input, Output>` |
| Uses Projection | Service injects Projection, not Repository |
| CA-safe output model | Output is read-only entity only when CA-safe; otherwise DTO fallback, never mutable domain entity |
| No @Service | Service has no Spring annotations |
| No @Repository | JPA Projection has no @Repository |

```
IF ANY CHECK FAILS:
  Fix the generated code
  Re-verify before writing
```

### Checkpoint 3: Post-Generation Verification

After writing the file:

```bash
# Compile check
cd ${projectRoot} && mvn compile -q -pl :${module} 2>&1 | head -20

# Verify no @Service annotation
grep -E "@Service|@Component" ${serviceFile}
# Should return empty

# Verify no Repository usage
grep "Repository<" ${serviceFile}
# Should return empty

# Verify extends Query
grep "extends Query<" ${useCaseFile}
# Should return the interface declaration
```

```
IF COMPILATION FAILS:
  Analyze error
  Fix and regenerate

IF REPOSITORY FOUND:
  Replace with Projection - queries should not use Repository
```

---

## GENERATION TEMPLATES

### Step 1: Parse Use Case Specification

Extract from use-case.yaml:
- `name`: Use case name (e.g., "GetProduct", "GetProducts")
- `type`: Must be "query"
- `aggregate`: Target aggregate name
- `input`: Query parameters
- `output`: Fields to return

### Step 2: Generate DTO Record (only for CA fallback or DTO-spec queries)

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port;

public record ${Name}ReadOnly(
    String ${field1},
    String ${field2}
    // ... other fields from output spec
) {
    public static ${Name}ReadOnly from(${Name}Data data) {
        return new ${Name}ReadOnly(
            data.get${Field1}(),
            data.get${Field2}()
        );
    }
}
```

### Step 3: Generate Projection Interface

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port.out.projection;

import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.${Name}ReadOnly;

public interface ${Name}Projection extends Projection<${Name}Projection.${Name}Input, ${ReturnType}> {

    class ${Name}Input implements ProjectionInput {
        // Input fields from spec
        public String ${inputField1};
    }

    // For single-item queries, add convenience method
    ${Name}ReadOnly findById(String id);
}
```

### Step 4: Generate JPA Projection

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.out.database.springboot.projection;

import org.springframework.data.jpa.repository.JpaRepository;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.${Name}ReadOnly;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.${Name}Mapper;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.out.${Name}Data;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.out.projection.${Name}Projection;

public interface Jpa${Name}Projection extends ${Name}Projection, JpaRepository<${Name}Data, String> {

    @Override
    default ${ReturnType} query(${Name}Input input) {
        // Implementation using Spring Data JPA
        List<${Name}Data> data = findBy${Criteria}(input.${field});
        return ${Name}Mapper.toReadOnly(data);
    }

    // For single-item queries
    @Override
    default ${Name}ReadOnly findById(String id) {
        return findById(id)
            .map(${Name}ReadOnly::from)
            .orElse(null);
    }

    // Spring Data JPA query methods
    List<${Name}Data> findBy${Criteria}(${CriteriaType} ${criteriaParam});
}
```

### Step 5: Generate UseCase Interface

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port.in;

import tw.teddysoft.ezddd.cqrs.usecase.query.Query;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.${Name}ReadOnly;

public interface ${UseCase}UseCase extends Query<${UseCase}UseCase.${UseCase}Input, ${UseCase}UseCase.${UseCase}Output> {

    class ${UseCase}Input implements Input {
        public String ${inputField1};

        public static ${UseCase}Input create() {
            return new ${UseCase}Input();
        }
    }

    class ${UseCase}Output extends CqrsOutput<${UseCase}Output> {
        private ${Name}ReadOnly ${nameCamelCase};  // or List<${Name}ReadOnly> for list queries

        public ${Name}ReadOnly get${Name}ReadOnly() { return ${nameCamelCase}; }
        public ${UseCase}Output set${Name}ReadOnly(${Name}ReadOnly dto) {
            this.${nameCamelCase} = dto;
            return this;
        }
    }
}
```

### Step 6: Generate Service Implementation

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.service;

import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${UseCase}UseCase;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.out.projection.${Name}Projection;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.${Name}ReadOnly;

import static tw.teddysoft.ucontract.Contract.*;

public class ${UseCase}Service implements ${UseCase}UseCase {

    private final ${Name}Projection projection;

    public ${UseCase}Service(${Name}Projection projection) {
        Objects.requireNonNull(projection);
        this.projection = projection;
    }

    @Override
    public ${UseCase}Output execute(${UseCase}Input input) {
        // Validate input
        requireNotNull("Input", input);
        requireNotNull("${InputField1}", input.${inputField1});

        // Query via projection
        var projectionInput = new ${Name}Projection.${Name}Input();
        projectionInput.${inputField1} = input.${inputField1};

        ${Name}ReadOnly dto = projection.query(projectionInput);
        return new ${UseCase}Output()
                .set${Name}ReadOnly(dto)
                .setId(input.${inputField1})
                .succeed();
    }
}
```

### Step 7: Update Bean Configuration

> **Shared Pattern** — See `references/rules/usecase-patterns.md` § Spring Configuration Pattern for the full UseCaseConfig template.

Add `@Bean` method for the query use case to `{Aggregate}UseCaseConfig.java`.

---

## EXAMPLE OUTPUT

For IDF specification requesting product list by user:

**ProductReadOnly.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.port;

public record ProductReadOnly(
    String productId,
    String name,
    String description,
    boolean isDeleted
) {
    public static ProductReadOnly from(ProductData data) {
        return new ProductReadOnly(
            data.getId(),
            data.getName(),
            data.getDescription(),
            data.isDeleted()
        );
    }
}
```

**ProductsProjection.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.port.out.projection;

import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnly;
import java.util.List;

public interface ProductsProjection extends Projection<ProductsProjection.ProductsInput, List<ProductReadOnly>> {

    class ProductsInput implements ProjectionInput {
        public String userId;
        public SortBy sortBy = SortBy.NAME;
        public SortOrder sortOrder = SortOrder.ASC;
    }

    enum SortBy { NAME, CREATED_DATE }
    enum SortOrder { ASC, DESC }
}
```

**GetProductsUseCase.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.port.in;

import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.query.Query;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnly;
import java.util.List;

public interface GetProductsUseCase extends Query<GetProductsUseCase.GetProductsInput, GetProductsUseCase.GetProductsOutput> {

    class GetProductsInput implements Input {
        public String userId;
        public String sortBy;
        public String sortOrder;

        public static GetProductsInput create() {
            return new GetProductsInput();
        }
    }

    class GetProductsOutput extends CqrsOutput<GetProductsOutput> {
        public List<ProductReadOnly> products;

        public static GetProductsOutput create() {
            return new GetProductsOutput();
        }

        public GetProductsOutput setProducts(List<ProductReadOnly> products) {
            this.products = products;
            return this;
        }
    }
}
```

**GetProductsService.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.service;

import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnly;
import tw.teddysoft.aiscrum.product.usecase.port.in.GetProductsUseCase;
import tw.teddysoft.aiscrum.product.usecase.port.out.projection.ProductsProjection;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import java.util.List;

import static tw.teddysoft.ucontract.Contract.*;

public class GetProductsService implements GetProductsUseCase {

    private final ProductsProjection projection;

    public GetProductsService(ProductsProjection projection) {
        Objects.requireNonNull(projection);
        this.projection = projection;
    }

    @Override
    public GetProductsOutput execute(GetProductsInput input) {
        requireNotNull("Input", input);

        var projectionInput = new ProductsProjection.ProductsInput();
        projectionInput.userId = input.userId;
        if (input.sortBy != null) {
            projectionInput.sortBy = ProductsProjection.SortBy.valueOf(input.sortBy);
        }
        if (input.sortOrder != null) {
            projectionInput.sortOrder = ProductsProjection.SortOrder.valueOf(input.sortOrder);
        }

        List<ProductReadOnly> products = projection.query(projectionInput);

        return GetProductsOutput.create()
            .setProducts(products)
            .setExitCode(ExitCode.SUCCESS);
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

When called by `code executor`:

```
code executor
    ↓
    Step 4.2 (IDF): Invoke query-skill
    ├─ Input: ${problemFramePath}/display/
    ├─ Output: UseCase, Service, Projection, JpaProjection, DTO
    └─ Next: Step 4.3 (usecase-test-skill)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| use-case.yaml not found | Report error, STOP |
| Not a query type | Report error, suggest command-skill |
| Missing output fields | Report error, STOP |
| Compilation error | Analyze, fix, retry (max 3 attempts) |
| Repository usage found | Replace with Projection |
| @Service annotation found | Remove - use @Bean |

---
