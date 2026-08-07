---
description: Safely create a git commit and snapshot branch after asking the user for the exact commit message, branch name, and confirmation. Use when the user wants to preserve the current repository state before risky changes.
allowed-tools: Bash
---

# Snapshot Branch Skill

Create a named branch that points at the current code state, then leave the user on the original branch unless they explicitly ask otherwise.

## Required safety flow

1. Run `git status --short --branch` and show the user what will be included.
2. Ask the user for the exact commit message. Do not suggest or invent one.
3. Ask the user for the exact branch name. Do not suggest or invent one.
4. Show the exact commands that will run.
5. Ask for explicit confirmation before running any command that commits, creates a branch, or pushes.
6. After completion, report the commit hash and branch name.

## Default command shape

Use non-interactive git commands:

```powershell
git status --short --branch
git add .
git commit -m "<user-provided message>"
git branch "<user-provided branch-name>"
```

Only push if the user explicitly confirms pushing:

```powershell
git push origin HEAD
git push origin "<user-provided branch-name>"
```

## Hard rules

- Never run `git commit`, `git branch`, or `git push` before the user provides the exact values and confirms.
- Never use a generated default commit message or branch name.
- Never use destructive git commands for this skill.
