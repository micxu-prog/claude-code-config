# Agentic Coding Config

Portable source-of-truth config for this Windows machine's agentic coding setup.

This repo started as a Claude Code and macOS Ghostty config repo. The Windows path is now **Copilot CLI-first** and uses **Zellij** as the terminal multiplexer. Claude Code and Ghostty files are kept for compatibility, but the primary setup is:

```text
Windows Terminal or PowerShell
  -> zellij
    -> copilot / shells / git / tests
```

For Linux-targeted work, use:

```text
Windows Terminal or PowerShell
  -> ssh azlinux-dev
    -> zellij
      -> development shells
```

## Windows quick install

Prerequisites:

- Git
- GitHub Copilot CLI
- PowerShell 7 recommended
- Windows Terminal or another stable terminal host
- Node.js, for MCP and LSP helpers
- Azure CLI, for the ADO MCP server

Clone and install:

```powershell
git clone https://github.com/michaelxu2288/claude-code-config.git $HOME\claude-code-config
Set-Location $HOME\claude-code-config

.\scripts\install-windows.ps1 -DryRun
.\scripts\install-windows.ps1 -Symlink
```

Install Zellij if it is not already installed:

```powershell
.\scripts\install-zellij-windows.ps1
```

Or install everything in one step:

```powershell
.\scripts\install-windows.ps1 -Symlink -InstallZellij
```

Symlink mode is the recommended mode for this machine because the repo is the source of truth. If Windows blocks symlink creation, the installer falls back to hard links for files. For true symlinks, enable Windows Developer Mode or run PowerShell as administrator. Copy mode is also available:

```powershell
.\scripts\install-windows.ps1 -Copy
```

## Daily commands

Recommended Windows workflow: start the agentic Zellij layout. It starts in locked/pass-through mode so Copilot owns input first.

```powershell
Set-Location $HOME\claude-code-config
zellij --layout agentic
```

Inside Zellij:

```text
Ctrl+g  unlock Zellij controls
Ctrl+p  pane controls
Ctrl+t  tab controls
Ctrl+g  lock again so Copilot owns input
```

Do not run raw `copilot` inside Zellij. Use the layout or `orz`; the wrapper starts Copilot with Windows/Zellij-safe settings.

Start Copilot directly without Zellij:

```powershell
copilot
```

For Linux-targeted work, put the multiplexer on the Linux VM:

```powershell
ssh azlinux-dev
zellij --layout agentic
```

## Update

```powershell
Set-Location $HOME\claude-code-config
git pull --ff-only
.\scripts\install-windows.ps1 -Symlink
```

## Managed Windows files

The Windows installer manages only user-editable config files. It does **not** manage Copilot auth, permissions, session history, logs, or cache files.

| Repo path | Installed path |
| --- | --- |
| `copilot\settings.json` | `%USERPROFILE%\.copilot\settings.json` |
| `copilot\copilot-instructions.md` | `%USERPROFILE%\.copilot\copilot-instructions.md` |
| `copilot\mcp-config.json` | `%USERPROFILE%\.copilot\mcp-config.json` |
| `copilot\lsp-config.json` | `%USERPROFILE%\.copilot\lsp-config.json` |
| `copilot\ado-mcp.cmd` | `%USERPROFILE%\.copilot\ado-mcp.cmd` |
| `copilot\statusline-command.*` | `%USERPROFILE%\.copilot\statusline-command.*` |
| `copilot\hooks\*` | `%USERPROFILE%\.copilot\hooks\*` |
| `copilot\agents\*` | `%USERPROFILE%\.copilot\agents\*` |
| `copilot\skills\*` | `%USERPROFILE%\.copilot\skills\*` |
| `zellij\config.kdl` | `%USERPROFILE%\.config\zellij\config.kdl` |
| `zellij\layouts\*` | `%USERPROFILE%\.config\zellij\layouts\*` |
| `powershell\profile.ps1` | CurrentUserAllHosts profiles under your Documents folder: `WindowsPowerShell\profile.ps1` and `PowerShell\profile.ps1` |
| `bin\orz.cmd` | `%USERPROFILE%\bin\orz.cmd` for `cmd.exe` and other non-PowerShell shells |
| `bin\orz-zellij.cmd` | `%USERPROFILE%\bin\orz-zellij.cmd` for launching Copilot safely inside Zellij |

## Copilot CLI setup

Copilot config in this repo is intentionally Copilot-native:

- `copilot\settings.json` configures model, reasoning effort, footer items, and a custom statusline.
- `copilot\copilot-instructions.md` contains global instructions tailored for Copilot CLI on this Windows machine.
- `copilot\agents\*.agent.md` uses Copilot custom agent format.
- `copilot\skills\<name>\SKILL.md` uses Copilot skill format.
- `copilot\hooks\*.json` uses Copilot hook format.
- `copilot\mcp-config.json` configures MCP servers.
- `copilot\lsp-config.json` configures optional LSP servers.

Verify Copilot:

```powershell
copilot version
copilot help config
copilot
```

Useful slash commands inside Copilot:

```text
/env
/statusline
/mcp show
/skills list
/agent
/lsp
```

Optional LSP dependencies:

```powershell
npm install -g pyright typescript typescript-language-server
```

## Zellij setup

Zellij uses KDL config. This repo installs:

- `zellij\config.kdl`
- `zellij\layouts\agentic.kdl`

The installer also sets:

```powershell
ZELLIJ_CONFIG_DIR=%USERPROFILE%\.config\zellij
```

Verify Zellij:

```powershell
zellij --version
zellij setup --check
zellij --config-dir $HOME\.config\zellij
```

### Zellij persistence model

Zellij detach is not the same thing as a terminal emulator surviving a reboot. Detach keeps the Zellij session alive while the Zellij server process is still running. Closing a terminal window can detach instead of killing the session, but a full Windows shutdown or reboot stops the local Zellij process and the processes inside it.

This config enables Zellij session serialization, which can help restore layout/session metadata after restart. It does not keep running commands alive through power-off. For work that must survive your local computer shutting down, run it on the Azure Linux VM, SSH into `azlinux-dev`, and run Zellij or tmux there while the VM stays on.

### Zellij keybindings for new users

This repo does not override Zellij's default keybindings. Useful defaults:

| Keys | Action |
| --- | --- |
| `Ctrl+g` | Toggle locked/pass-through mode. Locked mode lets Copilot own input. Press `Ctrl+g` to unlock Zellij controls, then `Ctrl+g` again to go back to Copilot. |
| `Alt+h` / `Alt+Left` | Move focus to the pane on the left, or previous tab if there is no left pane. |
| `Alt+l` / `Alt+Right` | Move focus to the pane on the right, or next tab if there is no right pane. |
| `Alt+j` / `Alt+Down` | Move focus to the pane below. |
| `Alt+k` / `Alt+Up` | Move focus to the pane above. |
| `Alt+n` | Create a new pane quickly. |
| `Ctrl+p`, then `n` | Enter pane mode and create a new pane. |
| `Ctrl+p`, then `x` | Close the focused pane. |
| `Ctrl+p`, then `h/j/k/l` or arrows | Move focus while in pane mode. |
| `Ctrl+p`, then `Esc` | Leave pane mode. |
| `Ctrl+t`, then `n` | Enter tab mode and create a new tab. |
| `Ctrl+t`, then `x` | Close the current tab. |
| `Ctrl+t`, then `h` / `l` or arrows | Move to previous/next tab. |
| `Ctrl+t`, then `Esc` | Leave tab mode. |
| `Ctrl+s`, then scroll or select text with mouse | Enter scroll mode for the focused pane; `Esc` leaves scroll mode, and selection copies to the Windows clipboard on mouse release. |
| `Alt+c` | Copy the current Zellij selection manually. |

Mental model:

- Use **Windows Terminal** for the outer window/tabs.
- Use **Zellij locked mode** as the normal Copilot mode.
- Press `Ctrl+g` only when you need Zellij pane/tab controls, then lock again.
- Use `Ctrl+g` if a Zellij shortcut seems to interfere with Copilot input.
- Use `Alt+h/j/k/l` as the main day-to-day pane navigation.

### Windows Terminal basics

These are the outer terminal shortcuts, before or around Zellij:

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+T` | New Windows Terminal tab. |
| `Ctrl+Shift+W` | Close the current tab or pane. |
| `Alt+Shift+D` | Split a new pane using the default profile. |
| `Alt+Shift+-` | Split horizontally. |
| `Alt+Shift+=` | Split vertically. |
| `Alt+Arrow` | Move focus between Windows Terminal panes. |
| `Alt+Shift+Arrow` | Resize the focused Windows Terminal pane. |
| `Ctrl+Shift+F` | Search terminal scrollback. |
| `Ctrl+Shift+C` | Copy selected text. |
| `Ctrl+Shift+V` | Paste. |
| `Ctrl+Plus` / `Ctrl+Minus` | Increase/decrease font size. |
| `Ctrl+0` | Reset font size. |
| `Ctrl+Shift+P` | Open the command palette. |

Avoid mixing too many Windows Terminal panes with Zellij panes. For agentic coding, prefer one Windows Terminal tab running Zellij, then split inside Zellij.

## PowerShell aliases

The repo installs a shared PowerShell profile for both Windows PowerShell and PowerShell 7. It restores common aliases/functions:

| Command | Action |
| --- | --- |
| `orz` | Launch Copilot through `agency copilot`, matching your previous PowerShell profile. |
| `ll`, `la` | List files including hidden files. |
| `l` | List files normally. |
| `gs` | `git status --short --branch` |
| `ga`, `gco`, `gb`, `gd`, `gl` | Common git add/checkout/branch/diff/log helpers. |
| `grep` | Uses `rg` if installed, otherwise `Select-String`. |
| `which` | `Get-Command` |
| `touch` | Create a file or update its timestamp. |
| `croot` | Go to `$HOME\claude-code-config`. |
| `agentic` | Go to the config repo and start/attach to Zellij. |

## ADO MCP

The repo-managed ADO MCP wrapper is:

```text
copilot\ado-mcp.cmd
```

It uses Azure CLI auth and does not contain tokens. Sign in separately:

```powershell
az login
```

Then verify inside Copilot:

```text
/mcp show
/mcp show ado
```

## Claude Code compatibility

Existing Claude Code files remain in `claude\`. The original macOS installer remains available as:

```bash
./install.sh
```

or:

```bash
./scripts/install-macos.sh
```

The Windows installer does not install Claude Code files by default. The Windows target is Copilot CLI.

## Ghostty status

`ghostty\config` is retained as legacy/macOS Ghostty config. winGhostty is not installed or configured by the Windows installer because it crashes on this machine.

## Safety notes

- Review machine-specific files before pushing this repo anywhere public.
- Do not commit tokens, API keys, credential files, Copilot internal state, session history, or logs.
- Keep credentials in Windows Credential Manager, Azure CLI, GitHub auth, or other secure stores.
