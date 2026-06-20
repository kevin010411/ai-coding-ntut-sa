# Query Use Case Generation Skill

## Overview

This skill generates Query Use Case components following CQRS read-side patterns:
- **UseCase Interface** - Port layer (inbound port)
- **Service Implementation** - Application service layer
- **Projection/outport dependency** - Load read-side state without violating Clean Architecture boundaries
- **Read-only Entity** - Query result model

Queries are **read-only** operations that never modify system state.

### Read-only Entity Rule

UseCase layer query outputs must use read-only entities, not DTOs.

- Do not generate DTO records, DTO projections, `toDto(...)` mapper methods, or DTO fallback types in the usecase layer.
- Return `readonlyProduct`, `List<readonlyProduct>`, or the spec-declared read-only entity type from the custom `CqrsOutput<T>` subclass.
- Load read-side state through a projection/outport, then convert it to a read-only entity before setting output.
- Do not expose the original mutable aggregate or child entity. A mutable entity leak is still forbidden.
- Return immutable collections for entity lists and nested entity collections.

### Read-only Necessity Check (Before Choosing Domain Models)

Before deciding which domain models need read-only wrappers, first decide whether read-only is needed at all.

Read-only exists to protect aggregate internals, especially child domain entities and collections reachable through an aggregate. Generate a read-only wrapper only when the query result would otherwise expose:

- a mutable aggregate root;
- a mutable child entity inside an aggregate;
- a collection, map, or nested object graph containing mutable domain entities;
- a domain object with public or package-visible mutation methods that could be reached by clients of the query result.

Do not generate extra read-only wrappers for simple values that are already safe to expose, such as primitives, strings, enums, immutable value objects, IDs, timestamps, or immutable collections of those safe values.

Decision order:
1. Inspect the query output object graph and identify whether it contains mutable aggregate/internal domain objects.
2. If there is no mutable aggregate/internal domain object to protect, do not invent additional read-only domain models.
3. If there is mutable aggregate/internal state to protect, wrap only the necessary boundary objects and nested mutable children with read-only entities.
4. Never use DTOs to solve usecase-layer query output concerns.

### Proxy Naming Rule

When using proxy/composition for read-only entities, use these names exactly:

- The shared interface keeps the original domain object name: `Product`, `Task`, `ProductGoal`.
- The real mutable implementation is named `Real*`: `RealProduct`, `RealTask`, `RealProductGoal`.
- The read-only proxy is named `readonly*`: `readonlyProduct`, `readonlyTask`, `readonlyProductGoal`.

The interface contains only query/read operations. Command/mutation operations belong on the `Real*` implementation or remain package-private behind aggregate methods; they must not be available through the original-name interface.

### Read-only Entity Implementation Approach

Use the proxy/composition approach for read-only entities:

1. Define the original-name interface with query/read methods only.
2. Implement mutable behavior in `Real*`.
3. Implement read-only protection in `readonly*`.
4. `readonly*` wraps the original-name interface or `Real*`, delegates query methods, wraps nested mutable children as `readonly*`, returns immutable collections, and never exposes the wrapped mutable object.
```java
class GetProductOutput extends CqrsOutput<GetProductOutput> {
    private readonlyProduct product;
    public readonlyProduct getProduct() { return product; }
    public GetProductOutput setProduct(readonlyProduct product) { this.product = product; return this; }
}

class GetProductsOutput extends CqrsOutput<GetProductsOutput> {
    private List<readonlyProduct> products = List.of();
    public List<readonlyProduct> getProducts() { return products; }
    public GetProductsOutput setProducts(List<readonlyProduct> products) {
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
| Read-only Entity | `src/main/java/{rootPackage}/{aggregate}/entity/readonly{Name}.java` |

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
        private readonlyProduct product;
        public readonlyProduct getProduct() { return product; }
        public GetProductOutput setProduct(readonlyProduct product) { this.product = product; return this; }
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
        readonlyProduct productReadOnly = new readonlyProduct(product);
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
        private List<readonlyProduct> products = List.of();
        public List<readonlyProduct> getProducts() { return products; }
        public static GetProductsOutput create() { return new GetProductsOutput(); }
        public GetProductsOutput setProducts(List<readonlyProduct> products) {
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
        List<readonlyProduct> products = productRepository.findAll().stream()
                .map(readonlyProduct::new)
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
        private List<readonlyTask> tasks;
        public List<readonlyTask> getTasks() { return tasks; }
        public GetTasksByDateOutput setTasks(List<readonlyTask> tasks) { this.tasks = tasks; return this; }
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

        List<readonlyTask> tasks = projection.query(projectionInput);
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
        private readonlyProduct product;
        public readonlyProduct getProduct() { return product; }
        public GetProductOutput setProduct(readonlyProduct product) { this.product = product; return this; }
    }
}

// ✅ CORRECT: List query — also uses CqrsOutput CRTP
public interface GetProductsUseCase extends Query<GetProductsUseCase.GetProductsInput, GetProductsUseCase.GetProductsOutput> {
    class GetProductsOutput extends CqrsOutput<GetProductsOutput> {  // CRTP!
        public List<readonlyProduct> products;
    }
}

// ❌ WRONG: Bare read-only entity without CqrsOutput wrapper
public interface GetProductUseCase extends Query<GetProductInput, readonlyProduct> { }  // Compilation error!

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
List<readonlyProduct> products = projection.query(input);

// For simple single-item lookup (custom method)
readonlyProduct product = projection.findById(productId);

// ❌ WRONG: Using execute() on Projection
List<readonlyProduct> products = projection.execute(input);  // WRONG method name!
```

**Rationale:** `query()` is the standard method defined by `Projection<I, O>` interface.

### Rule 4: Never Modify State in Queries

```java
// ✅ CORRECT: Read-only query
@Override
public readonlyProduct execute(GetProductInput input) {
    return projection.findById(input.productId);  // Read only
}

// ❌ WRONG: Modifying state in query
@Override
public readonlyProduct execute(GetProductInput input) {
    Product product = repository.findById(...).orElseThrow();
    product.incrementViewCount();  // FORBIDDEN! State modification
    repository.save(product);      // FORBIDDEN! Writing in query
    return new readonlyProduct(product);
}
```

**Rationale:** Queries must be side-effect free for CQRS compliance.

### Rule 5: Return Read-only Entity (wrapped in CqrsOutput), NOT Mutable Domain Entity

```java
// ✅ CORRECT: Read-only entity wrapped in CqrsOutput Output class
public interface GetProductUseCase extends Query<..., GetProductUseCase.GetProductOutput> {
    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private readonlyProduct product;  // read-only entity inside CqrsOutput wrapper
    }
}

// ✅ CORRECT: Read-only entity wrapped in CqrsOutput when spec declares readOnlyEntities
public interface GetProductUseCase extends Query<..., GetProductUseCase.GetProductOutput> {
    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private readonlyProduct product;  // Read-only entity view, not mutable Product
    }
}

// ✅ CORRECT: Projection returns read-only entity (Projection is not constrained by CqrsOutput)
public interface ProductProjection extends Projection<..., readonlyProduct> {
    readonlyProduct findById(String productId);
}

// ❌ WRONG: Returning mutable domain entity
public interface GetProductUseCase extends Query<..., Product> {  // Mutable entity leak!
}

// ❌ WRONG: Bare DTO as Query output (violates CqrsOutput constraint)
public interface GetProductUseCase extends Query<..., readonlyProduct> {  // Compilation error!
}
```

**Rationale:** Mutable domain entities must not leak outside the aggregate boundary. Query Output must extend `CqrsOutput<T>` (CRTP). Read-only entity is the required usecase-layer read model when mutable aggregate/internal domain state must be protected. DTOs are not allowed in the usecase layer.

### Rule 6: No @Service or @Repository Annotations

> **Shared Rule** — See `references/rules/usecase-patterns.md` § No @Service or @Component Annotation

Additionally for Query: JPA Projection interfaces must NOT use `@Repository` — Spring Data JPA auto-implements the interface.

### Rule 7: Projection Interface Structure

```java
// ✅ CORRECT: Projection interface in port/out/projection
package tw.teddysoft.aiscrum.product.usecase.port.out.projection;

public interface ProductsProjection extends Projection<ProductsProjection.Input, List<readonlyProduct>> {

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
    default List<readonlyProduct> query(Input input) {
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

### Rule 9: No DTO in UseCase Layer

UseCase layer query outputs must not introduce DTOs.

```java
// ✅ CORRECT: Output wraps read-only entity
class GetProductOutput extends CqrsOutput<GetProductOutput> {
    private readonlyProduct product;
    public readonlyProduct getProduct() { return product; }
    public GetProductOutput setProduct(readonlyProduct product) { this.product = product; return this; }
}

// ❌ WRONG: DTO in usecase layer
public record ProductDto(String productId, String name) {}

// ❌ WRONG: mapper names DTO intent
ProductDto toDto(ProductData data) { ... }
```

**Rationale:** The usecase layer exposes domain-safe read-only entities. DTOs belong only at adapter/API boundaries when controllers need request/response transport shapes.
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
        private readonlyProduct product;

        public readonlyProduct getProduct() { return product; }
        public GetProductOutput setProduct(readonlyProduct product) {
            this.product = product;
            return this;
        }
    }
}

// ❌ WRONG: Raw CqrsOutput without CRTP type parameter
class GetProductOutput extends CqrsOutput {  // Missing <GetProductOutput>!
    // Compilation warning + fluent methods return wrong type
}

// ❌ WRONG: Returning bare read-only entity when framework requires CqrsOutput subtype
public interface GetProductUseCase extends Query<GetProductInput, readonlyProduct> {
    // Compilation error: readonlyProduct doesn't extend CqrsOutput
}

// ❌ WRONG: Using Optional as return type
public interface GetProductUseCase extends Query<GetProductInput, Optional<readonlyProduct>> {
    // Compilation error: Optional doesn't extend CqrsOutput
}
```

**Why CRTP?** `CqrsOutput<T>` 的 fluent setter 方法（如 `setId()`, `succeed()`, `setExitCode()`）
回傳 `T` 而非 `CqrsOutput`，讓呼叫者不需要強制轉型：

```java
// With CRTP: fluent methods return the concrete type
GetProductOutput output = new GetProductOutput()
    .setProduct(product)        // returns GetProductOutput
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
| Read-only output model | Output uses read-only entity when mutable aggregate internals need protection; never DTO and never mutable domain entity |
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

### Step 2: Generate Read-only Entity Proxy

Generate this only after the Read-only Necessity Check says mutable aggregate/internal domain state must be protected.

```java
package ${rootPackage}.${aggregateLowerCase}.entity;

public interface ${Name} {
    String get${Field1}();
    String get${Field2}();
}

public final class Real${Name} implements ${Name} {
    // Mutable domain implementation; command methods are not declared on ${Name}.
}

public final class readonly${Name} implements ${Name} {
    private final ${Name} source;

    public readonly${Name}(${Name} source) {
        this.source = Objects.requireNonNull(source, "${Name} cannot be null");
    }

    public String get${Field1}() { return source.get${Field1}(); }
    public String get${Field2}() { return source.get${Field2}(); }
}
```
### Step 3: Generate Projection Interface

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port.out.projection;

import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;
import ${rootPackage}.${aggregateLowerCase}.entity.readonly${Name};

public interface ${Name}Projection extends Projection<${Name}Projection.${Name}Input, ${ReturnType}> {

    class ${Name}Input implements ProjectionInput {
        // Input fields from spec
        public String ${inputField1};
    }

    // For single-item queries, add convenience method
    readonly${Name} findById(String id);
}
```

### Step 4: Generate JPA Projection

```java
package ${rootPackage}.${aggregateLowerCase}.adapter.out.database.springboot.projection;

import org.springframework.data.jpa.repository.JpaRepository;
import ${rootPackage}.${aggregateLowerCase}.entity.readonly${Name};
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
    default readonly${Name} findById(String id) {
        return findById(id)
            .map(readonly${Name}::new)
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
import ${rootPackage}.${aggregateLowerCase}.entity.readonly${Name};

public interface ${UseCase}UseCase extends Query<${UseCase}UseCase.${UseCase}Input, ${UseCase}UseCase.${UseCase}Output> {

    class ${UseCase}Input implements Input {
        public String ${inputField1};

        public static ${UseCase}Input create() {
            return new ${UseCase}Input();
        }
    }

    class ${UseCase}Output extends CqrsOutput<${UseCase}Output> {
        private readonly${Name} ${nameCamelCase};  // or List<readonly${Name}> for list queries

        public readonly${Name} get${Name}() { return ${nameCamelCase}; }
        public ${UseCase}Output set${Name}(readonly${Name} ${nameCamelCase}) {
            this.${nameCamelCase} = ${nameCamelCase};
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
import ${rootPackage}.${aggregateLowerCase}.entity.readonly${Name};

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

        readonly${Name} ${nameCamelCase} = projection.query(projectionInput);
        return new ${UseCase}Output()
                .set${Name}(${nameCamelCase})
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

For IDF specification requesting product list by user where Product exposes mutable aggregate/internal state:

**Product.java:**
```java
package tw.teddysoft.aiscrum.product.entity;

public interface Product {
    ProductId getProductId();
    String getName();
    boolean isDeleted();
}
```

**RealProduct.java:**
```java
package tw.teddysoft.aiscrum.product.entity;

public final class RealProduct extends EsAggregateRoot<ProductId, ProductEvents> implements Product {
    // Mutable aggregate implementation. Command methods are not declared on Product.
}
```

**readonlyProduct.java:**
```java
package tw.teddysoft.aiscrum.product.entity;

public final class readonlyProduct implements Product {
    private final Product source;

    public readonlyProduct(Product source) {
        this.source = Objects.requireNonNull(source, "Product cannot be null");
    }

    public ProductId getProductId() { return source.getProductId(); }
    public String getName() { return source.getName(); }
    public boolean isDeleted() { return source.isDeleted(); }
}
```

**ProductsProjection.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.port.out.projection;

import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;
import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;
import tw.teddysoft.aiscrum.product.entity.readonlyProduct;
import java.util.List;

public interface ProductsProjection extends Projection<ProductsProjection.ProductsInput, List<readonlyProduct>> {
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
import tw.teddysoft.aiscrum.product.entity.readonlyProduct;
import java.util.List;

public interface GetProductsUseCase extends Query<GetProductsUseCase.GetProductsInput, GetProductsUseCase.GetProductsOutput> {
    class GetProductsInput implements Input {
        public String userId;
        public String sortBy;
        public String sortOrder;
        public static GetProductsInput create() { return new GetProductsInput(); }
    }

    class GetProductsOutput extends CqrsOutput<GetProductsOutput> {
        private List<readonlyProduct> products = List.of();
        public List<readonlyProduct> getProducts() { return products; }
        public GetProductsOutput setProducts(List<readonlyProduct> products) {
            this.products = List.copyOf(products);
            return this;
        }
    }
}
```

**GetProductsService.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.service;

import tw.teddysoft.aiscrum.product.entity.readonlyProduct;
import tw.teddysoft.aiscrum.product.usecase.port.in.GetProductsUseCase;
import tw.teddysoft.aiscrum.product.usecase.port.out.projection.ProductsProjection;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import java.util.List;
import java.util.Objects;

import static tw.teddysoft.ucontract.Contract.*;

public class GetProductsService implements GetProductsUseCase {
    private final ProductsProjection projection;

    public GetProductsService(ProductsProjection projection) {
        this.projection = Objects.requireNonNull(projection);
    }

    @Override
    public GetProductsOutput execute(GetProductsInput input) {
        requireNotNull("Input", input);
        var projectionInput = new ProductsProjection.ProductsInput();
        projectionInput.userId = input.userId;
        List<readonlyProduct> products = projection.query(projectionInput);
        return new GetProductsOutput()
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
    ├─ Output: UseCase, Service, Projection, JpaProjection, read-only entity
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
