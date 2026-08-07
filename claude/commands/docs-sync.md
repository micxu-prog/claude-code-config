---
description: Reconcile this session's durable work into the C:\Users\t-michaelxu\docs\ knowledge base on demand. Invokes the read/write docs-writer subagent to surgically update the project wiki, after snapshotting docs\ as an undo net. The manual, in-session counterpart to the automatic SessionEnd docs-writer hook.
allowed-tools: Bash, Task
---

# /docs-sync — update the project docs from this session

Bring the `C:\Users\t-michaelxu\docs\` knowledge base up to date with the durable knowledge
produced in THIS session, on demand (you don't have to wait for session end).

## Flow

1. **Snapshot first (undo net).** The docs corpus is NOT a git repo, so back it up before
   any edit. Run this Bash command and capture the printed backup path:

   ```bash
   powershell -NoProfile -Command "$s=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $b=\"C:\Users\t-michaelxu\.claude\docs-backups\$s\"; New-Item -ItemType Directory -Force -Path $b | Out-Null; Copy-Item -Path 'C:\Users\t-michaelxu\docs\*' -Destination $b -Recurse -Force; Write-Output $b"
   ```

   If the backup fails, STOP and tell the user — do not let the writer edit unprotected.

2. **Dispatch the writer.** Launch the `docs-writer` subagent via the Task tool. Hand it a
   detailed instruction (not a thin one), telling it to reconcile THIS session's work into the
   docs. Because this is in-session, the writer reads the live conversation — it does NOT need a
   transcript file. Include in the Task prompt:
   - That it is doing an on-demand `/docs-sync` of the current session.
   - A 1-2 paragraph summary, in YOUR words, of what this session actually accomplished that
     might be durable (proofs that passed/failed, config values confirmed or corrected,
     commands/paths discovered, contradictions resolved, status changes). This primes the writer;
     it still applies its own durable-vs-ephemeral judgment.
   - The backup path from step 1, so it knows edits are reversible.
   - A reminder of its hard rules: edit ONLY inside `docs\`, never commit/delete/wholesale-rewrite,
     prefer editing existing files, honor the authority hierarchy (project\CLAUDE.md = present
     state, nodepool0-vm-template-progress.md = append-only log), date entries today, and that a
     NO-OP is a valid and common outcome — do not invent changes.

3. **Relay the writer's CHANGE REPORT** to the user verbatim-ish (FILES CHANGED / WHAT WAS
   CAPTURED / DELIBERATELY SKIPPED / CONTRADICTIONS RESOLVED / REVIEW). Remind them the edits are
   uncommitted local changes they should review, and give them the backup path in case they want
   to revert.

## Notes

- This is the manual twin of the automatic SessionEnd hook
  (`~/.claude/hooks/docs-writer-sessionend.ps1`). Same writer agent, same backup discipline; the
  difference is this runs now, in-session, with full live context, and lets you review before you
  walk away.
- If the user names a specific topic/file to focus on, pass that scope to the writer.
- Do not commit anything. Surfacing the diff for the user to commit is the end of this command.
