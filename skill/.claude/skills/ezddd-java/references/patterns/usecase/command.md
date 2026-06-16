# Command Use Case Generation Skill

## Overview

This skill generates Command Use Case components following Clean Architecture:
- **UseCase Interface** - Port layer (inbound port)
- **Service Implementation** - Application service layer

Commands modify system state through Aggregates and return `CqrsOutput`.

---

## INPUT

| Source | Path |
|--------|------|
| CBF Frame | `JSON spec` |
| SWF Frame | `JSON spec` |
| Use Case Spec | `JSON spec `useCase`` |

---

## OUTPUT

| File | Location |
|------|----------|
| UseCase Interface | `src/main/java/{rootPackage}/{aggregate}/usecase/port/in/{UseCase}UseCase.java` |
| Service Implementation | `src/main/java/{rootPackage}/{aggregate}/usecase/service/{UseCase}Service.java` |

---

## COMMAND CATEGORIES

### Category 1: Create Command

**Creates a new Aggregate Root.**

```java
// Service pattern for Create
public CqrsOutput<?> execute(CreateProductInput input) {
    requireNotNull("Input", input);
    requireNotNull("Product name", input.name);

    try {
        var output = CqrsOutput.create();
        ProductId productId = ProductId.valueOf(input.id);

        // Check ID doesn't already exist — return failure, not throw
        if (repository.findById(productId).isPresent()) {
            output.setId(input.id)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Create product failed: product already exists, product id = " + input.id);
            return output;
        }

        Product product = new Product(productId, input.name);
        repository.save(product);

        output.setId(input.id).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}
```

### Category 2: Update Command

**Modifies an existing Aggregate Root.**

```java
// Service pattern for Update
public CqrsOutput<?> execute(RenameProductInput input) {
    requireNotNull("Input", input);
    requireNotNull("Product id", input.productId);
    requireNotNull("New name", input.newName);

    try {
        var output = CqrsOutput.create();
        Product product = repository.findById(ProductId.valueOf(input.productId)).orElse(null);
        if (null == product) {
            output.setId(input.productId)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Rename product failed: product not found, product id = " + input.productId);
            return output;
        }

        product.rename(input.newName, input.userId);
        repository.save(product);

        output.setId(input.productId).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}
```

### Category 3: Delete Command

**Soft-deletes an Aggregate Root.**

```java
// Service pattern for Delete
public CqrsOutput<?> execute(DeleteProductInput input) {
    requireNotNull("Input", input);
    requireNotNull("Product id", input.productId);

    try {
        var output = CqrsOutput.create();
        Product product = repository.findById(ProductId.valueOf(input.productId)).orElse(null);
        if (null == product) {
            output.setId(input.productId)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Delete product failed: product not found, product id = " + input.productId);
            return output;
        }

        product.delete(input.userId);
        repository.save(product);

        output.setId(input.productId).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}
```

### Category 4: Child Entity Command

**Operates on child entities within an Aggregate.**

```java
// Service pattern for Child Entity operations
public CqrsOutput<?> execute(AddTaskInput input) {
    requireNotNull("Input", input);
    requireNotNull("Plan id", input.planId);
    requireNotNull("Task name", input.taskName);

    try {
        var output = CqrsOutput.create();
        Plan plan = repository.findById(PlanId.valueOf(input.planId)).orElse(null);
        if (null == plan) {
            output.setId(input.planId)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Add task failed: plan not found, plan id = " + input.planId);
            return output;
        }

        plan.addTask(input.projectName, input.taskName, input.userId);
        repository.save(plan);

        output.setId(plan.getLastCreatedTaskId().toString()).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}
```

---

## CRITICAL RULES (Embedded - Cannot Be Skipped)

### Rule 1: UseCase Interface Structure

```java
// ✅ CORRECT: Interface extends Command with Input as inner class
public interface CreateProductUseCase extends Command<CreateProductUseCase.CreateProductInput, CqrsOutput<?>> {

    class CreateProductInput implements Input {
        public String id;
        public String name;
        public String userId;

        public static CreateProductInput create() {
            return new CreateProductInput();
        }
    }
}

// ❌ WRONG: Input as separate file
// CreateProductInput.java  ← WRONG! Should be inner class

// ❌ WRONG: Not extending Command
public interface CreateProductUseCase {  // Missing extends Command<...>
    CqrsOutput<?> execute(CreateProductInput input);
}

// ❌ WRONG: Using record for Input
public interface CreateProductUseCase extends Command<CreateProductUseCase.CreateProductInput, CqrsOutput<?>> {
    record CreateProductInput(String id, String name) implements Input { }  // WRONG! Use class
}
```

**Rationale:**
- Input as inner class keeps it colocated with the use case
- `Command<I, O>` interface provides standard execute method
- Class (not record) allows mutable fields for builder pattern

### Rule 2: No @Service or @Component Annotation

> **Shared Rule** — See `references/rules/usecase-patterns.md` § No @Service or @Component Annotation

### Rule 3: Constructor Injection with Null Validation

```java
// ✅ CORRECT: Constructor injection with Objects.requireNonNull
public class CreateProductService implements CreateProductUseCase {
    private final Repository<Product, ProductId> repository;

    public CreateProductService(Repository<Product, ProductId> repository) {
        this.repository = Objects.requireNonNull(repository);
    }
}

// ❌ WRONG: Field injection
@Autowired
private Repository<Product, ProductId> repository;

// ❌ WRONG: No validation
public CreateProductService(Repository<Product, ProductId> repository) {
    this.repository = repository;  // No null check!
}
```

**Rationale:** Constructor injection is explicit, testable, and allows fail-fast validation.

### Rule 4: Input Validation in execute() Method

```java
// ✅ CORRECT: Validate all required inputs
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    // Null checks (UseCase layer — fail fast before business logic)
    requireNotNull("Input", input);
    requireNotNull("Product id", input.id);
    requireNotNull("Product name", input.name);
    requireNotNull("User id", input.userId);

    // ⚠️ Business rule validation (e.g. require("Name not blank", ...)) belongs in Aggregate layer,
    //    not here. UseCase execute() only does null checks with requireNotNull().

    // ... business logic
}

// ❌ WRONG: No input validation
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    Product product = new Product(ProductId.valueOf(input.id), input.name);
    // Will fail with NPE if input.id is null!
}
```

**Rationale:** Fail fast with clear error messages before any business logic.

### Rule 5: Repository Pattern - Only 3 Standard Methods

```java
// ✅ CORRECT: Use standard Repository methods (findById, save, delete)
Repository<Product, ProductId> repository;

// Load — use orElse(null) + null check, return failure output if not found
Product product = repository.findById(productId).orElse(null);

// Save
repository.save(product);

// Delete (less common — most DDD uses soft-delete via domain event)
repository.delete(product);

// ❌ WRONG: Custom query methods
repository.findByName(name);  // NOT ALLOWED!
repository.findAll();         // NOT ALLOWED!
repository.existsById(id);    // NOT ALLOWED!
```

**Rationale:**
- Repository is for Write Model only
- Use Projection/Inquiry for complex queries
- Maintains Event Sourcing integrity

### Rule 6: Create Command - Check ID Doesn't Exist

```java
// ✅ CORRECT: Check for duplicate ID, return failure output
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    try {
        var output = CqrsOutput.create();
        ProductId productId = ProductId.valueOf(input.id);

        if (repository.findById(productId).isPresent()) {
            output.setId(input.id)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Create product failed: product already exists, product id = " + input.id);
            return output;
        }

        Product product = new Product(productId, input.name);
        repository.save(product);
        output.setId(input.id).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}

// ❌ WRONG: No existence check
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    Product product = new Product(ProductId.valueOf(input.id), input.name);
    repository.save(product);  // May overwrite existing!
}
```

**Rationale:** Prevents accidental overwriting of existing aggregates.

### Rule 7: Update/Delete Command - Load Before Modify

```java
// ✅ CORRECT: Load, modify, save pattern — return failure if not found
@Override
public CqrsOutput<?> execute(RenameProductInput input) {
    try {
        var output = CqrsOutput.create();
        Product product = repository.findById(ProductId.valueOf(input.productId)).orElse(null);
        if (null == product) {
            output.setId(input.productId)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Rename product failed: product not found, product id = " + input.productId);
            return output;
        }

        product.rename(input.newName, input.userId);
        repository.save(product);
        output.setId(input.productId).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}

// ❌ WRONG: Create new instead of loading
@Override
public CqrsOutput<?> execute(RenameProductInput input) {
    // This creates a NEW aggregate, losing all history!
    Product product = new Product(ProductId.valueOf(input.productId), input.newName);
    repository.save(product);
}
```

**Rationale:** Event Sourcing requires loading existing state before modifications.

### Rule 8: CqrsOutput Return Pattern

> **兩種等價寫法** — `.setExitCode(ExitCode.SUCCESS)` 等同於 `.succeed()`；`.setExitCode(ExitCode.FAILURE)` 等同於 `.fail()`。
> 完整 API 參見 `references/rules/framework-api.md` § CqrsOutput API。

```java
// ✅ CORRECT: Fluent style (succeed/fail) — recommended
return CqrsOutput.create()
    .setId(productId.toString())
    .succeed();

// ✅ CORRECT: Explicit style (setExitCode) — also valid
return CqrsOutput.create()
    .setId(productId.toString())
    .setExitCode(ExitCode.SUCCESS);

// For failures:
return CqrsOutput.create()
    .setMessage("Product name cannot be empty")
    .fail();
// or equivalently:
return CqrsOutput.create()
    .setMessage("Product name cannot be empty")
    .setExitCode(ExitCode.FAILURE);

// ❌ WRONG: Custom output class
return new CreateProductOutput(productId, true);  // Don't create custom outputs

// ❌ WRONG: Not setting ExitCode
return CqrsOutput.create().setId(productId.toString());  // Missing ExitCode!
```

**Rationale:** Standardized output enables consistent error handling and controller responses.

### Rule 8.5: Preconditions MUST Be OUTSIDE try Block

> **⛔ CRITICAL — COMMON FIRST-GEN FAILURE CAUSE ⛔**
> `requireNotNull` 等 precondition 驗證**必須**放在 `try` block **外面**。
> Precondition violation 是程式錯誤（programming error），不應被 `catch` 為業務例外。

```java
// ✅ CORRECT: Preconditions outside try
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    requireNotNull("Input", input);           // ← OUTSIDE try
    requireNotNull("Product id", input.id);   // ← OUTSIDE try

    try {
        // Business logic only inside try
        ...
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}

// ❌ WRONG: Preconditions inside try — contract violations get swallowed as UseCaseFailureException
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    try {
        requireNotNull("Input", input);       // ← WRONG: inside try
        ...
    } catch (Exception e) {
        throw new UseCaseFailureException(e); // Swallows PreconditionViolationException!
    }
}
```

### Rule 9: Blanket Catch — Exception Handling with UseCaseFailureException

> **Pattern**: 業務錯誤透過 `CqrsOutput` + `ExitCode.FAILURE` 回傳（正常 return）；
> 只有非預期的技術錯誤被 blanket catch 捕捉並包裝為 `UseCaseFailureException`。

```java
// ✅ CORRECT: Blanket catch — business errors return failure output, unexpected errors throw
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    requireNotNull("Input", input);

    try {
        var output = CqrsOutput.create();
        ProductId productId = ProductId.valueOf(input.id);

        // Business error → return failure output (not throw)
        if (repository.findById(productId).isPresent()) {
            output.setId(input.id)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("Create product failed: product already exists, product id = " + input.id);
            return output;
        }

        Product product = new Product(productId, input.name);
        repository.save(product);

        output.setId(input.id).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        // Unexpected errors only — blanket catch
        throw new UseCaseFailureException(e);
    }
}

// ❌ WRONG: Swallowing unexpected exceptions in catch block
@Override
public CqrsOutput<?> execute(CreateProductInput input) {
    try {
        // ...
    } catch (Exception e) {
        return CqrsOutput.create().setExitCode(ExitCode.FAILURE);  // Loses exception details!
    }
}

// ❌ WRONG: Throwing IAE for business errors (not blanket catch pattern)
if (repository.findById(productId).isPresent()) {
    throw new IllegalArgumentException("Already exists");  // Use return failure output instead
}
```

**Rationale:**
- Business errors are expected outcomes → return `CqrsOutput` with `FAILURE` + descriptive message
- Unexpected errors (DB failure, etc.) → `UseCaseFailureException` preserves stack trace for debugging
- Blanket catch keeps try-catch semantics pure: catch = "system broke"

### Rule 10: Package Location

> **Shared Rule** — See `references/rules/usecase-patterns.md` § Package Location Rules

---

## VERIFICATION CHECKPOINTS

### Checkpoint 1: Input Validation

Before generating code, verify:

| Check | Command | Expected |
|-------|---------|----------|
| use-case.yaml exists | `test -f ${usecaseYamlPath}` | File exists |
| Has command type | `grep "type: command" ${usecaseYamlPath}` | Found |
| Has input fields | `grep "input:" ${usecaseYamlPath}` | Found |

```
IF ANY CHECK FAILS:
  Report error: "Invalid use-case.yaml: missing required field"
  STOP - do not proceed
```

### Checkpoint 2: Pre-Generation Verification

Before writing any file:

| Check | Verification |
|-------|--------------|
| No @Service annotation | Service class has no Spring annotations |
| Input is inner class | Input defined inside UseCase interface |
| Extends Command | Interface extends `Command<Input, CqrsOutput>` |
| Constructor has Objects.requireNonNull | All dependencies validated |
| execute() validates input | All required fields checked |

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

# Verify Input is inner class
grep "class.*Input implements Input" ${useCaseFile}
# Should return the Input class declaration
```

```
IF COMPILATION FAILS:
  Analyze error
  Fix and regenerate

IF @SERVICE FOUND:
  Remove annotation - use @Bean configuration instead
```

---

## GENERATION TEMPLATES

### Step 1: Parse Use Case Specification

Extract from use-case.yaml:
- `name`: Use case name (e.g., "CreateProduct")
- `type`: Must be "command"
- `aggregate`: Target aggregate name
- `input`: Input field definitions
- `preconditions`: Validation rules
- `postconditions`: Expected outcomes

### Step 2: Generate UseCase Interface

```java
package ${rootPackage}.${aggregateLowerCase}.usecase.port.in;

import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface ${UseCase}UseCase extends Command<${UseCase}UseCase.${UseCase}Input, CqrsOutput<?>> {

    class ${UseCase}Input implements Input {
        // Fields from input specification
        public String ${field1};
        public String ${field2};
        // ... other fields

        public static ${UseCase}Input create() {
            return new ${UseCase}Input();
        }
    }
}
```

### Step 3: Generate Service Implementation

**For Create Command:**
```java
package ${rootPackage}.${aggregateLowerCase}.usecase.service;

import ${rootPackage}.${aggregateLowerCase}.entity.${Aggregate};
import ${rootPackage}.${aggregateLowerCase}.entity.${Aggregate}Id;
import ${rootPackage}.${aggregateLowerCase}.usecase.port.in.${UseCase}UseCase;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.in.interactor.UseCaseFailureException;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import java.util.Objects;

import static tw.teddysoft.ucontract.Contract.*;

public class ${UseCase}Service implements ${UseCase}UseCase {

    private final Repository<${Aggregate}, ${Aggregate}Id> repository;

    public ${UseCase}Service(Repository<${Aggregate}, ${Aggregate}Id> repository) {
        this.repository = Objects.requireNonNull(repository);
    }

    @Override
    public CqrsOutput<?> execute(${UseCase}Input input) {
        // ⛔ Preconditions MUST be OUTSIDE try block — contract violations are programming errors, not business exceptions
        requireNotNull("Input", input);
        requireNotNull("${field1}", input.${field1});
        // ... validate other required fields

        try {
            var output = CqrsOutput.create();
            ${Aggregate}Id id = ${Aggregate}Id.valueOf(input.id);

            // Business error → return failure output (not throw)
            if (repository.findById(id).isPresent()) {
                output.setId(input.id)
                        .setExitCode(ExitCode.FAILURE)
                        .setMessage("Create ${aggregateCamelCase} failed: ${aggregateCamelCase} already exists, ${aggregateCamelCase} id = " + input.id);
                return output;
            }

            ${Aggregate} ${aggregateCamelCase} = new ${Aggregate}(id, input.${field2});
            repository.save(${aggregateCamelCase});

            output.setId(input.id).setExitCode(ExitCode.SUCCESS);
            return output;
        } catch (Exception e) {
            throw new UseCaseFailureException(e);
        }
    }
}
```

**For Update Command:**
```java
@Override
public CqrsOutput<?> execute(${UseCase}Input input) {
    requireNotNull("Input", input);
    requireNotNull("${Aggregate} id", input.${aggregateCamelCase}Id);
    // ... validate other required fields

    try {
        var output = CqrsOutput.create();
        ${Aggregate} ${aggregateCamelCase} = repository.findById(${Aggregate}Id.valueOf(input.${aggregateCamelCase}Id)).orElse(null);
        if (null == ${aggregateCamelCase}) {
            output.setId(input.${aggregateCamelCase}Id)
                    .setExitCode(ExitCode.FAILURE)
                    .setMessage("${UseCase} failed: ${aggregateCamelCase} not found, ${aggregateCamelCase} id = " + input.${aggregateCamelCase}Id);
            return output;
        }

        ${aggregateCamelCase}.${method}(input.${param}, input.userId);
        repository.save(${aggregateCamelCase});

        output.setId(input.${aggregateCamelCase}Id).setExitCode(ExitCode.SUCCESS);
        return output;
    } catch (Exception e) {
        throw new UseCaseFailureException(e);
    }
}
```

### Step 4: Generate Bean Configuration (if not exists)

> **Shared Pattern** — See `references/rules/usecase-patterns.md` § Spring Configuration Pattern for the full UseCaseConfig template.

Check if `{Aggregate}UseCaseConfig.java` exists. If not, create it following the shared template. If exists, add new `@Bean` method to existing config.

---

## EXAMPLE OUTPUT

For use-case.yaml:
```yaml
name: CreateProduct
type: command
aggregate: Product
input:
  - name: id
    type: String
    required: true
  - name: name
    type: String
    required: true
  - name: userId
    type: String
    required: true
```

**CreateProductUseCase.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.port.in;

import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface CreateProductUseCase extends Command<CreateProductUseCase.CreateProductInput, CqrsOutput<?>> {

    class CreateProductInput implements Input {
        public String id;
        public String name;
        public String userId;

        public static CreateProductInput create() {
            return new CreateProductInput();
        }
    }
}
```

**CreateProductService.java:**
```java
package tw.teddysoft.aiscrum.product.usecase.service;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.usecase.port.in.CreateProductUseCase;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.in.interactor.UseCaseFailureException;
import tw.teddysoft.ezddd.usecase.port.out.repository.Repository;

import java.util.Objects;

import static tw.teddysoft.ucontract.Contract.*;

public class CreateProductService implements CreateProductUseCase {

    private final Repository<Product, ProductId> repository;

    public CreateProductService(Repository<Product, ProductId> repository) {
        this.repository = Objects.requireNonNull(repository);
    }

    @Override
    public CqrsOutput<?> execute(CreateProductInput input) {
        requireNotNull("Input", input);
        requireNotNull("Product id", input.id);
        requireNotNull("Product name", input.name);
        requireNotNull("User id", input.userId);

        try {
            var output = CqrsOutput.create();
            ProductId productId = ProductId.valueOf(input.id);

            if (repository.findById(productId).isPresent()) {
                output.setId(input.id)
                        .setExitCode(ExitCode.FAILURE)
                        .setMessage("Create product failed: product already exists, product id = " + input.id);
                return output;
            }

            Product product = new Product(productId, input.name);
            repository.save(product);

            output.setId(input.id).setExitCode(ExitCode.SUCCESS);
            return output;
        } catch (Exception e) {
            throw new UseCaseFailureException(e);
        }
    }
}
```

---

## INTEGRATION WITH ORCHESTRATOR

When called by `code executor`:

```
code executor
    ↓
    Step 4.2: Invoke command-skill
    ├─ Input: ${problemFramePath}/machine/use-case.yaml
    ├─ Output: ${UseCase}UseCase.java, ${UseCase}Service.java
    └─ Next: Step 4.3 (usecase-test-skill)
```

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| use-case.yaml not found | Report error, STOP |
| Not a command type | Report error, suggest query-skill |
| Missing input fields | Report error, STOP |
| Compilation error | Analyze, fix, retry (max 3 attempts) |
| @Service annotation found | Remove and add @Bean to config |

---
