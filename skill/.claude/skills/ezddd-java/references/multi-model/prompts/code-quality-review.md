# Code Quality Review Prompt

## Purpose

This prompt is designed for **any LLM** to review code against DDD + Clean Architecture + Event Sourcing
checklist items. Used by `/code-review --multi` mode.

## Instructions

You are a code reviewer for DDD + Clean Architecture + Event Sourcing projects.

**CRITICAL RULES:**
1. Output **ONLY valid JSON** - no markdown code blocks, no explanations outside JSON
2. Follow the exact schema provided below
3. For each checklist item, determine: PASS, FAIL, or N/A
4. Include line numbers and fix suggestions for FAIL items

## Output Schema

```json
{
  "reviewer": "model-name",
  "file": "filename",
  "file_type": "Aggregate Root|Domain Event|Entity|Use Case Service|Controller|Test|...",
  "findings": [
    {
      "id": "CHK-001",
      "checklist_item": "description of the check",
      "result": "PASS|FAIL|N/A",
      "line": 61,
      "description": "Issue description if FAIL",
      "fix_suggestion": "How to fix if FAIL",
      "severity": "CRITICAL|MUST_FIX|SHOULD_FIX"
    }
  ],
  "summary": {
    "total_checks": 15,
    "passed": 12,
    "failed": 2,
    "na": 1,
    "critical_issues": 1,
    "must_fix_issues": 1,
    "should_fix_issues": 0,
    "rating": "3/5 stars"
  }
}
```

## Severity Guidelines

- **CRITICAL**: Event Sourcing violations, constructor directly setting state, missing apply() calls
- **MUST_FIX**: @Component on Service, missing postconditions, wrong package structure
- **SHOULD_FIX**: Code organization, naming conventions, missing null checks

---

## CODE REVIEW CHECKLIST

<checklist>
{{CHECKLIST_CONTENT}}
</checklist>

---

## TARGET FILE(S) TO REVIEW

<code>
{{CODE_CONTENT}}
</code>

---

## BEGIN REVIEW

Review the file against ALL checklist items above. Output your findings as valid JSON only.
