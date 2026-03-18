---
name: snapshot-branch
description: Commit current state and create a named branch at that point, then continue on main. Useful for preserving a working version before making many changes.
user-invocable: true
---

# Snapshot Branch Skill

Create a snapshot of the current code state as a branch before continuing development.

## Instructions

1. First, check git status to see what changes exist and show the user
2. **MANDATORY: Ask the user these questions BEFORE running any git commands:**
   - "What do you want the commit message to be?"
   - "What do you want the branch name to be?"
3. Wait for user to provide BOTH answers
4. Show the exact commands that will be run:
   ```
   git add .
   git commit -m "<their message>"
   git branch <branch-name>
   git push origin main
   git push origin <branch-name>
   ```
5. Ask for explicit confirmation before executing
6. After completion, remind the user how to retrieve this snapshot later:
   ```
   git clone <repo-url> /path/to/new-folder
   cd /path/to/new-folder
   git checkout <branch-name>
   ```

## CRITICAL
- NEVER run git commit, git branch, or git push without first asking the user for the exact message/name
- NEVER use default or suggested values without user confirmation
- Always show commands before running
- Report the commit hash for reference
