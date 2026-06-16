# Code Review Workflow

## Default Mode Execution Flow

**DO NOT skip any step. Violations invalidate the review.**

### Step 1: Identify File Type

Match the file against patterns:

| File Pattern | Category | Priority |
|-------------|----------|----------|
| `**/entity/{Aggregate}.java` | Aggregate Root | CRITICAL |
| `**/entity/*Events.java` | Domain Event | CRITICAL |
| `**/entity/*Id.java` | Value Object (ID) | HIGH |
| `**/entity/*.java` (other) | Entity / Value Object | MEDIUM |
| `**/usecase/service/*.java` | Use Case Service | HIGH |
| `**/usecase/port/in/*.java` | Use Case Interface | MEDIUM |
| `**/controller/*.java` | Controller | MEDIUM |
| `**/*Test.java` | Test | MEDIUM |
| `**/*ContractTest.java` | Contract Test | HIGH |
| `**/usecase/port/*Mapper.java` | Mapper | LOW |
| `**/*Data.java` | Data Class (PO) | MEDIUM |
| `**/*RepositoryConfig*.java` | Repository Config | LOW |

### Step 2: Read Corresponding Checklist

Navigate to `checklist.md` and find the section matching the file type.

### Step 3: Read the Target File

```
READ: [target file path]
```

Analyze the code against the checklist.

### Step 4: Execute Test (if applicable)

```bash
mvn test -Dtest=[TestClassName] -q
```

- Verify BUILD SUCCESS
- Check for test failures
- If tests fail, the review cannot proceed

### Step 5: Build Checklist Comparison Table

Create a table documenting each check:

```markdown
| Check Item | Result | Location | Issue Description |
|------------|--------|----------|-------------------|
| Constructor sets state directly? | FAIL | line 61-74 | Direct assignment |
| Uses apply(event) to trigger when()? | PASS | line 106 | Correct |
| State assignment only in when()? | FAIL | line 61-74 | State set in constructor |
```

### Step 6: Categorize Issues

**CRITICAL** (Must Fix Immediately):
- Event Sourcing violations
- Constructor directly setting state
- Missing apply() calls

**MUST FIX** (High Priority):
- @Component on Service classes
- Missing postconditions (ensure)
- Wrong package structure

**SHOULD FIX** (Medium Priority):
- Code organization
- Missing null checks
- Naming conventions

### Step 7: Generate Review Report

```markdown
## Code Review Report: [FileName]

### Test Status: [PASSING/FAILING]
- [Test execution details]

### Compliance Check: [COMPLIANT/NON-COMPLIANT]

### Issues Found

#### CRITICAL Issues
1. [Issue description with line numbers]
   - Current: [problematic code]
   - Expected: [correct code]

#### MUST FIX Issues
1. [Issue description]

#### SHOULD FIX Issues
1. [Issue description]

### Summary
- Critical Issues: X
- Must Fix Issues: Y
- Should Fix Issues: Z
- Rating: [1-5 stars]

### Recommendations
[Specific fix suggestions with code examples]
```

---

## Parallel Layer Mode (--parallel)

When `--parallel` flag is provided or when reviewing 3+ files across multiple layers,
execute parallel review by Clean Architecture layer.

**Full workflow**: See [parallel-layer-review.md](parallel-layer-review.md)

**Quick summary**:
1. Classify files by layer (domain / usecase / infra / test / frontend)
2. Launch one Task agent per layer (all in parallel, `run_in_background: true`)
3. Each agent reviews its layer's files against the relevant checklist section
4. Main agent performs cross-layer checks after all agents complete
5. Aggregate into unified report, rating = min(all layer ratings)

**When to use**:
- 3+ files across 2+ architectural layers
- PR review / `review all changes`
- Manual: `review --parallel`

**When NOT to use**:
- 1-2 files (overhead > benefit)
- All files in same layer (no parallelization benefit)

---

## Multi-Model Mode (--multi)

When `--multi` flag is provided, execute parallel review with 4 LLMs.

> **Dispatch engine**: `references/multi-model/dispatch.md`
> **Prompt strategy**: `references/multi-model/prompts/code-quality-review.md`
> **Consensus algorithm**: `references/multi-model/aggregators/weighted-consensus.md`
> **Output policy**: `references/multi-model/context-conservation.md`

### Step M1: Prepare Review Context (code-quality specific)

```
1. Read checklist.md to identify file type
2. Read corresponding checklist section
3. **For Aggregate Review**: Scan ALL files in entity/ directory
   - Use glob: **/[aggregate]/entity/*.java
   - Categorize each file (see aggregate-review.md)
   - Skip enum files (*State.java that are enums)
   - Include ALL other .java files
4. Read ALL target file(s) content
5. Create review session: .dev/reviews/code-review/{aggregate}-{YYYYMMDD-HHMMSS}/
```

### Step M2: Generate Multi-Model Prompt

Use the `code-quality-review.md` prompt template:
- Insert CHECKLIST_CONTENT from checklist.md (matching file type section)
- Insert CODE_CONTENT with complete file content(s)
- Save to `$REVIEW_DIR/prompt.txt` and copy to `/tmp/code_review_prompt.txt`

### Steps M3-M6: Dispatch, Collect, Arbitrate, Report

**Delegate to shared dispatch engine** (`references/multi-model/dispatch.md`):
- `{PROMPT_FILE}` = `$REVIEW_DIR/prompt.txt`
- `{REVIEW_DIR}` = `.dev/reviews/code-review/{id}`
- `{REVIEW_TYPE}` = `code-quality`

The dispatch engine handles:
- Phase 2: Parallel 4-LLM dispatch (Gemini CLI, ChatGPT API, Codex CLI, Claude sub-agent)
- Phase 3: Result collection and JSON parsing
- Phase 4: Weighted consensus aggregation and Claude arbitration
- Phase 5: Report generation (file only) + compact conversation summary

**Consensus thresholds for code-quality reviews:**
- >= 3/4 models agree -> Confirmed (must fix)
- 2/4 models agree -> Likely (should fix)
- 1/4 models agree -> Disputed (Claude arbitrates)
- 1/4 models report only -> Unique (log only)
