---
name: spec-interview
argument-hint: [instructions]
description: Interview user in-depth to create a detailed spec. Use when the user wants to define requirements, create a specification, plan a feature, or needs help thinking through implementation details before coding.
allowed-tools: AskUserQuestion, Write
---

# Spec Interview Skill

Follow the user instructions and interview me in detail using the AskUserQuestion tool about literally anything: technical implementation, UI & UX, concerns, tradeoffs, etc. but make sure the questions are not obvious. Be very in-depth and continue interviewing me continually until it's complete. Then, write the spec to a file.

<instructions>$ARGUMENTS</instructions>

## Interview Approach

- Ask probing, non-obvious questions
- Cover technical implementation details
- Explore UI/UX considerations
- Discuss concerns and tradeoffs
- Dig into edge cases and error handling
- Clarify scope and boundaries
- Understand success criteria
- Keep interviewing until the picture is complete

## Output

When the interview is complete, write a detailed spec file that captures all the information gathered. The spec should be comprehensive enough to serve as the foundation for implementation planning.
