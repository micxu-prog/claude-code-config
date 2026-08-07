---
name: spec-interview
description: Interview the user in depth to create a detailed specification before implementation. Use when the user wants requirements, a feature spec, or help thinking through design before coding.
---

# Spec Interview Skill

Use this skill to gather requirements and produce a high-quality implementation specification.

## Interview approach

- Ask one focused question at a time.
- Prefer specific multiple-choice questions when the likely options are clear.
- Ask non-obvious questions about behavior, scope, edge cases, failure modes, data ownership, security, rollout, validation, and maintainability.
- Keep interviewing until the implementation boundaries and success criteria are clear.
- Do not start implementation while using this skill unless the user explicitly switches from specification to implementation.

## Spec output

When enough context is gathered, write a Markdown spec file at the path the user requests. If no path is specified, ask where to save it.

The spec should include:

- Problem statement
- Goals and non-goals
- User workflows
- Functional requirements
- Edge cases and error handling
- Technical approach
- Files/components likely to change
- Validation plan
- Open questions

