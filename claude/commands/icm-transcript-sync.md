---
description: Extract a hackathon meeting transcript into the ICM project docs. Takes a transcript path (.docx/.txt/.vtt/.md) as $ARGUMENTS, snapshots docs\ as an undo net, then dispatches the icm-transcript-extractor subagent to read it and write a dated extraction md under intern-hackathon-icm\docs\project\.
allowed-tools: Bash, Task
---

# /icm-transcript-sync — extract a meeting transcript into the ICM project docs

Capture a meeting transcript for the **Incident Knowledge Onboarding for Azure SRE Agent**
project into a clean, dated markdown file. This is the on-demand wrapper around the
`icm-transcript-extractor` subagent.

## Input

`$ARGUMENTS` should be the **path to the transcript** (e.g.
`C:\Users\t-michaelxu\Downloads\transcript.docx`). Accepts `.docx`, `.txt`, `.vtt`/`.srt`,
`.md`. If no path is given, ask the user for one (or for pasted transcript text), then proceed.

## Flow

1. **Snapshot first (undo net).** The docs corpus is not its own git repo state you want to
   risk; back it up before the writer touches anything. Run and capture the printed path:

   ```bash
   STAMP=$(date -u +%Y%m%dT%H%M%SZ); B="/c/Users/t-michaelxu/.claude/icm-docs-backups/$STAMP"; mkdir -p "$B" && cp -r /c/Users/t-michaelxu/intern-hackathon-icm/docs/* "$B"/ && echo "BACKUP=$B"
   ```
   If the backup fails, STOP and tell the user.

2. **Dispatch the extractor.** Launch the `icm-transcript-extractor` subagent via the Task tool.
   Hand it: the transcript path from `$ARGUMENTS` (verbatim), a one-line note that this is an
   on-demand `/icm-transcript-sync`, and the backup path so it knows edits are reversible.
   Remind it of its hard rules: read the source for real (use the docx `office/unpack.py` path
   for .docx, verify non-empty), extract everything useful, write ONE dated extraction md under
   `intern-hackathon-icm\docs\project\`, flag MCP-Server-Engineer-relevant items + any
   auto-transcription unreliability, never fabricate, never commit, never touch other docs.

3. **Relay the extractor's report** to the user: meeting title/date, attendees, the top
   takeaways (esp. what's NEW vs the written docs), MCP-role-relevant items, and the output file
   path. Mention the backup path in case they want to revert, and note the edits are uncommitted.

## Notes

- Don't commit anything — surfacing the new doc for the user to review is the end of this command.
- If the user wants the new transcript intel folded into CONTEXT.md / the integration brief
  (not just captured standalone), that's a follow-up `/icm-docs-sync`, not this command.
