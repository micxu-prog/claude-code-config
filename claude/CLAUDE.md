# Global Claude Code Instructions

## About Me
- Name: micxu@nvidia.com Michael Xu

## Acronym Tracking
- Whenever you encounter ANY acronym you are not 100% sure about, APPEND it to `~/Desktop/Acronyms.md`
- Format: one line per acronym -> `ACRONYM (context where you found it)`
- Only append, never overwrite or reorganize the file

## Preferences
- Be concise and direct
- No emojis
- make sure to NEVER submit ANY CL or even shelves CL in p4 without my permission!!! most of the time just show me the command to run and i can manually do it, i dont want to trigger any auto testing or reviewing pipelines that way
- NEVER run git commit, git branch, git push, or any git command that requires a message/name without FIRST asking me what the commit message or branch name should be. Always ask, never use defaults or suggestions without my explicit input.
## Coding Style
- Use clear, readable code
- Add comments only when logic isn't self-evident, comments should be ALL lowercase/casual except for acronyms

## Common Tools & Tech
- all of my current work is in 1 monorepo in p4 /Users/micxu/perforce/micxu_myfirstworkspace
## Startup Tasks
- Always check p4 login and sync at session start:
  ```bash
  cd /Users/micxu/perforce/micxu_myfirstworkspace && p4 login -s && p4 sync -n | head -5
  ```
- Must run p4 commands from workspace directory (where .p4config lives)

## Notes
<!-- Add any other context you want Claude to always know -->
- whenever I send a confluence link, make sure you can read/open the contents or let me know before you start working
- look through confluence MCP ONLY when directed

## Wine for InitChk (Mac)
Running Windows initchk.exe on Mac via Wine works fine. Ignore these benign Wine warnings:
```
err:winediag:getaddrinfo Failed to resolve your host name IP
err:wineboot:process_run_key Error running cmd L"C:\\windows\\system32\\winemenubuilder.exe -a -r" (2).
```
These don't affect execution.

Usage:
```bash
cd /path/to/folder && wine ./initchk.exe input.rom output.dmp 2>&1
```

If you see `exception code c0000409` (STATUS_STACK_BUFFER_OVERRUN) - that's the EXE crashing, NOT Wine.
- GB202 ROMs crash initchk v1.433.0 at "Memory index search method : MEMINFO STRAP"
- This is a known bug in initchk.exe itself (confirmed crashes on native Windows too)
- Contact: jbrown (Jacquie Brown) - initchk maintainer