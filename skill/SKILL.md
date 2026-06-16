---
name: ai-coding-exercise-skills-uc-v1-product-readonly
description: |
  TeddySoft AI coding exercise workflow variant. Use this version to generate code where only Product get queries return read-only entities; other queries still use DTO/projection outputs.
---

# AI Coding Exercise Skills UC V1 Product ReadOnly

## Version Policy

Only Product get-product and get-products queries use read-only entity outputs. All other query use cases use projection + DTO + mapper outputs.

This skill packages the full TeddySoft AI coding exercise repository as one Codex skill.

## When To Use

Use this skill when the task involves:

- Executing or explaining the UC workflow from `.claude/commands/execute-uc.md`.
- Generating Java + Spring Boot + ezddd DDD code from `.dev/specs/**`.
- Reviewing generated code against the repository's ezddd patterns and rules.
- Checking API consistency between JSON specs and Spring Boot controllers.
- Studying or applying the course materials in `.dev/course`, `.dev/lessons`, and `.dev/adr`.
- Working with the AI Scrum running example contained in this repository.

## How To Use

Start with these internal references as needed:

- `.claude/skills/ezddd-java/SKILL.md` for the main Java + ezddd workflow.
- `.claude/skills/api-consistency-checker/SKILL.md` for API spec/controller consistency checks.
- `.claude/commands/execute-uc.md` for use-case execution.
- `.claude/commands/init-project.md` for project initialization.
- `.dev/project-config.json` for project-level settings.
- `.dev/specs/` for use-case, adapter, and entity specifications.
- `.dev/course/execute-uc-workflow.md` for the course workflow.
- `README.md` and `CLAUDE.md` for repository-level guidance.

Treat the nested `.claude/skills/*` directories as internal modules of this single skill rather than separate top-level Codex skills.
