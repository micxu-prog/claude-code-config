---
name: caffeinate
description: "Keep this Windows machine awake (prevent sleep) for a set duration or indefinitely, optionally with the laptop lid closed — like macOS `caffeinate`. Use whenever the user wants to stop the computer from sleeping, keep it running with the lid shut/closed/down, keep Claude agents / Windows Terminal / a long job alive overnight or while away, or asks to 'caffeinate', 'keep my computer on', 'don't let it sleep', 'stay awake for X minutes/hours'. Parse the duration (e.g. '10 minutes', '2 hours', 'forever') and whether the lid is open or closed from the request, then run the bundled `caffeinate` command. Windows-only; lid-closed mode needs admin (auto-prompts UAC). Do NOT use for macOS/Linux, for scheduling recurring tasks, or for waking a machine up."
---

# caffeinate — keep this Windows PC awake

## What this does

Wraps the user's `caffeinate` command at `C:\Users\t-michaelxu\bin\caffeinate.cmd`
(PowerShell implementation in `caffeinate.ps1`, already on PATH). It uses the Win32
`SetThreadExecutionState` API to block idle sleep, and — for lid-closed mode —
temporarily flips the power policy's lid-close action to "do nothing", restoring it
automatically on exit (Ctrl+C, timer end, or window close).

This is the Windows equivalent of macOS `caffeinate`. The primary use case is keeping
**Claude agents inside Windows Terminal running with the laptop lid shut**.

## When to use it

Trigger on intents like:
- "keep my computer on for 30 minutes" → `caffeinate 30m`
- "stay awake with the lid closed" / "keep running with lid shut" → `caffeinate` (default is lid-shut, forever)
- "don't let my laptop sleep for 2 hours" → `caffeinate 2h`
- "caffeinate for 10 min but I'm leaving the lid open" → `caffeinate 10m -NoLid`
- "keep the agents alive overnight" → `caffeinate` (indefinite, lid-shut)

## How to parse the request → command

The command is:

```
caffeinate [DURATION] [-NoLid] [-Display] [-Quiet]
```

1. **DURATION** — translate the user's words to one token:
   - "10 minutes" / "10 min" → `10m`
   - "30 seconds" → `30s`
   - "2 hours" / "2 hr" → `2h`
   - a bare number means **minutes** (`5` → 5 minutes)
   - "forever" / "indefinitely" / "until I stop it" / unspecified → **omit DURATION** (runs until Ctrl+C)

2. **Lid** — decide lid-closed vs lid-open:
   - lid **closed/shut/down**, or not mentioned (overnight-agent default) → **omit** `-NoLid` (lid-shut is the default; needs admin, auto-prompts UAC)
   - lid will stay **open**, or the user wants to avoid the admin prompt → add `-NoLid`

3. **Optional flags:**
   - keep the **screen on** too → `-Display` (only meaningful lid-open)
   - **no banner** → `-Quiet`

### Examples

| User says | Run this |
|-----------|----------|
| "keep computer on 10 minutes, lid off" | `caffeinate 10m` |
| "stay awake 10 min, lid stays open" | `caffeinate 10m -NoLid` |
| "keep my agents running with the lid down" | `caffeinate` |
| "don't sleep for 90 minutes" | `caffeinate 90m` |
| "caffeinate 2 hours, screen on, lid open" | `caffeinate 2h -NoLid -Display` |

## Running it

- **From the agent's Bash tool, always invoke the `.ps1` directly** — the bare `caffeinate` shim is a
  `.cmd` and does NOT resolve in the agent's bash shell (`command not found` / exit 127). Use:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\t-michaelxu\bin\caffeinate.ps1" <DURATION> [flags]`
- In the **user's own Windows Terminal** (PowerShell/cmd) the short form `caffeinate 10m` works, since `bin` is on PATH.
- This is a **blocking, foreground** process — it holds the keep-awake for its whole lifetime,
  so run it with `run_in_background: true` (otherwise it ties up the turn for the full duration).
- For **lid-closed** mode without admin, the command relaunches itself in an elevated window via a
  UAC prompt; tell the user to accept it and keep that window open.

```bash
# example (agent/bash): 20 minutes, lid open, background
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\t-michaelxu\bin\caffeinate.ps1" 20m -NoLid
```

## Important notes / caveats

- **Windows-only.** Built around `SetThreadExecutionState` + `powercfg`. Don't use on mac/Linux.
- **Lid-closed needs admin.** The lid-close action is a system power policy. Lid-open (`-NoLid`) needs no admin.
- **Auto-restores.** On exit the original lid-close action and normal sleep behavior are put back —
  even if the window is closed with the X (a console-control handler covers that, not just `finally`).
- **Don't close the window early** if you want it to keep holding the machine awake.
- It does **not** wake a sleeping machine or schedule anything — it only holds the current session awake.
- If elevation is cancelled, fall back to `caffeinate <dur> -NoLid` (lid must stay open) or launch from an admin terminal.

## Files

- `C:\Users\t-michaelxu\bin\caffeinate.cmd` — thin launcher (matches the `azl` wrapper pattern).
- `C:\Users\t-michaelxu\bin\caffeinate.ps1` — implementation (duration parsing, UAC self-elevation, flag math, restore-on-exit).
