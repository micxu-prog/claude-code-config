# Claude Code Config

Portable configuration files for [Claude Code](https://claude.com/claude-code) and [Ghostty](https://ghostty.org) terminal. Clone this repo on any Mac and run `install.sh` to symlink everything into place.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Install](#quick-install)
- [Manual Install](#manual-install)
- [File Reference](#file-reference)
  - [CLAUDE.md](#claudemd)
  - [settings.json](#settingsjson)
  - [settings.local.json](#settingslocaljson)
  - [statusline-command.sh](#statusline-commandsh)
  - [Agents](#agents)
  - [Commands](#commands)
  - [Scripts](#scripts)
  - [Skills](#skills)
  - [Ghostty Config](#ghostty-config)
- [Ghostty SAND Keybindings](#ghostty-sand-keybindings)
- [Customization](#customization)
- [Updating](#updating)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Make sure these are installed before running the installer.

### 1. Homebrew (package manager)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After install, follow the instructions to add Homebrew to your PATH (it prints them at the end).

### 2. Node.js (for Claude Code CLI)

```bash
brew install node
```

Verify: `node --version` should print a version number (v20+ recommended).

### 3. Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

Verify: `claude --version` should print a version number.

After installing, run `claude` once to complete the initial authentication flow. It will open a browser window to log in to your Anthropic account.

### 4. Ghostty Terminal

Download from [ghostty.org](https://ghostty.org) and drag to Applications.

Alternatively, if you have Homebrew:
```bash
brew install --cask ghostty
```

Verify: open Ghostty from Applications, or run `/Applications/Ghostty.app/Contents/MacOS/ghostty --version`.

### 5. JetBrains Mono Nerd Font

The Ghostty config uses this font. Without it, you'll see fallback fonts.

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

Verify: open Font Book (Cmd+Space, type "Font Book") and search for "JetBrains". You should see "JetBrainsMono Nerd Font".

### 6. jq (JSON processor)

Used by the statusline script to parse Claude Code's context data.

```bash
brew install jq
```

Verify: `jq --version` should print a version number.

### 7. Git

macOS ships with Git, but you can get a newer version:
```bash
brew install git
```

---

## Quick Install

```bash
# 1. clone the repo
git clone <YOUR_REPO_URL> ~/claude-code-config
cd ~/claude-code-config

# 2. preview what will happen (no changes made)
./install.sh --dry-run

# 3. actually install (creates symlinks, backs up existing files)
./install.sh
```

That's it. Open Ghostty and run `claude` to verify everything works.

---

## Manual Install

If you prefer to set things up by hand instead of using the installer script.

### Step 1: Create directories

```bash
mkdir -p ~/.claude/{agents,commands,scripts,skills}
mkdir -p ~/.config/ghostty
```

### Step 2: Copy or symlink each file

For each file below, either copy it or create a symlink. Symlinks are recommended so that `git pull` automatically updates your config.

```bash
# symlink approach (recommended)
ln -sf /path/to/claude-code-config/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf /path/to/claude-code-config/claude/settings.json ~/.claude/settings.json
ln -sf /path/to/claude-code-config/claude/settings.local.json ~/.claude/settings.local.json
ln -sf /path/to/claude-code-config/claude/statusline-command.sh ~/.claude/statusline-command.sh
ln -sf /path/to/claude-code-config/claude/agents/pdf-to-markdown.md ~/.claude/agents/pdf-to-markdown.md
ln -sf /path/to/claude-code-config/claude/commands/chrome-js.md ~/.claude/commands/chrome-js.md
ln -sf /path/to/claude-code-config/claude/scripts/confluence-update.py ~/.claude/scripts/confluence-update.py
ln -sf /path/to/claude-code-config/claude/skills/snapshot-branch.md ~/.claude/skills/snapshot-branch.md
ln -sf /path/to/claude-code-config/claude/skills/spec-interview.md ~/.claude/skills/spec-interview.md
ln -sf /path/to/claude-code-config/claude/skills/verify-telemetry.md ~/.claude/skills/verify-telemetry.md
ln -sf /path/to/claude-code-config/ghostty/config ~/.config/ghostty/config
```

Replace `/path/to/claude-code-config` with the actual path where you cloned this repo.

### Step 3: Verify

```bash
# check symlinks are correct
ls -la ~/.claude/CLAUDE.md
ls -la ~/.config/ghostty/config

# test claude code starts
claude --version

# test ghostty config loads (if Ghostty is running, reload with Cmd+Shift+,)
```

---

## File Reference

### CLAUDE.md

**Location:** `~/.claude/CLAUDE.md`
**Purpose:** Global instructions that Claude Code follows in every conversation, across all projects.

This file defines:
- **Identity**: your name and email (update this for your account)
- **Preferences**: response style (concise, no emojis), safety guards (never auto-commit, never auto-submit CLs)
- **Coding style**: clear code, lowercase comments except acronyms
- **Startup tasks**: commands Claude runs at the start of each session (p4 login check, sync)
- **Tool-specific notes**: Perforce workspace path, Wine/initchk usage for cross-platform ROM tools, Confluence MCP behavior

**What to customize on a new machine:**
- Update `Name:` with your email/name
- Update the Perforce workspace path under "Common Tools & Tech" and "Startup Tasks"
- Remove or update the Wine/initchk section if not applicable

---

### settings.json

**Location:** `~/.claude/settings.json`
**Purpose:** Core Claude Code settings -- model selection, plugins, statusline, and feature flags.

Current configuration:
```
model: opus[1m]              -- uses Claude Opus with 1M context window
alwaysThinkingEnabled: true  -- extended thinking always on
effortLevel: high            -- high reasoning effort
```

**Plugins enabled:**
- `clangd-lsp@claude-plugins-official` -- C/C++ language server support
- `the-village@gfw` -- NVIDIA GFW team agent framework
- `generate-t5t@gfw` -- T5T generation tool
- `nvidia-service-integrations@gfw` -- Slack, Jira, GitLab, Confluence, Calendar integrations

**Statusline:** runs `statusline-command.sh` to show version, context %, model, directory, and git branch in the terminal.

**Environment variables:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` -- enables experimental agent teams feature

**What to customize:**
- Model: change `"model"` to `"sonnet"` or `"haiku"` for cheaper/faster responses
- Plugins: remove NVIDIA-specific plugins if not at NVIDIA. Keep `clangd-lsp` if you work with C/C++.

---

### settings.local.json

**Location:** `~/.claude/settings.local.json`
**Purpose:** Permission allowlists and sandbox configuration. These control which tools Claude Code can use without asking for confirmation.

**How it works:** When you approve a tool use in Claude Code (e.g., clicking "Allow" for a bash command), it gets added to the `permissions.allow` list. Over time this file grows as you use Claude Code. The version in this repo is a cleaned-up starting point with common permissions.

**Sandbox settings:**
```json
"sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true
}
```
This means bash commands run in a restricted sandbox by default, but are auto-approved since the sandbox prevents damage.

**What to customize:**
- You generally don't need to edit this file manually. Just use Claude Code and approve tools as needed -- the file grows automatically.
- Remove any NVIDIA-specific MCP permissions if not at NVIDIA.

---

### statusline-command.sh

**Location:** `~/.claude/statusline-command.sh`
**Purpose:** Bash script that renders the colorful statusline at the bottom of Claude Code.

**What it shows (left to right):**
| Section | Color | Example |
|---------|-------|---------|
| Version | Blue | `V1.0.42` |
| Context | Orange | `Context: 23%` |
| Model | Purple | `(Opus 4.6 (1M context))` |
| Directory | Green | `Dir: /Users/you/project` |
| Git Branch | Yellow | `Branch: main` |
| AutoYes | Green/Red | `AutoYes: ON` (only if active) |

**Dependencies:** requires `jq` to parse the JSON input from Claude Code.

**How to customize colors:** edit the ANSI color codes in the `# --- ANSI colors (256-color) ---` section. Use [256-color chart](https://www.ditig.com/256-colors-cheat-sheet) for reference.

---

### Agents

#### pdf-to-markdown (`claude/agents/pdf-to-markdown.md`)

**Location:** `~/.claude/agents/pdf-to-markdown.md`
**Purpose:** Specialized sub-agent for converting PDF documents into faithful Markdown reproductions.

**How to invoke:** Just ask Claude to convert a PDF:
```
convert this PDF to markdown: ~/Downloads/my-document.pdf
```

Claude automatically delegates to this agent. It handles:
- Text extraction with structural fidelity (headings, lists, tables)
- OCR for scanned PDFs or image-based content
- Diagrams reproduced as Mermaid or ASCII art
- Code blocks with proper language tags
- Complete transcription -- never truncates or summarizes

---

### Commands

#### chrome-js (`claude/commands/chrome-js.md`)

**Location:** `~/.claude/commands/chrome-js.md`
**Purpose:** Custom command to execute JavaScript in the frontmost Google Chrome tab via AppleScript.

**How to invoke:**
```
/chrome-js
```
Then tell Claude what to extract from the page.

**Common uses:**
- Extract dropdown/select options from web forms
- Scrape table data from a webpage
- Run arbitrary JS in Chrome's console and get results back

**Requirements:** Google Chrome must be open with the target page in the active tab.

---

### Scripts

#### confluence-update.py (`claude/scripts/confluence-update.py`)

**Location:** `~/.claude/scripts/confluence-update.py`
**Purpose:** Converts Markdown to Confluence storage format (XHTML) and pushes it to a Confluence page via REST API.

**Usage:**
```bash
python3 ~/.claude/scripts/confluence-update.py <page-id> <markdown-file> [--dry-run] [--output FILE] [--title TITLE]
```

**Examples:**
```bash
# preview the conversion without pushing
python3 ~/.claude/scripts/confluence-update.py 12345 my-doc.md --dry-run --output preview.html

# push to confluence
python3 ~/.claude/scripts/confluence-update.py 12345 my-doc.md
```

**Auth setup:**
1. Generate a Confluence API token at https://id.atlassian.com/manage-profile/security/api-tokens
2. Save the token:
   ```bash
   mkdir -p ~/.ai-pim-utils/confluence
   echo "YOUR_TOKEN_HERE" > ~/.ai-pim-utils/confluence/token
   chmod 600 ~/.ai-pim-utils/confluence/token
   ```

**What to customize:**
- Edit `USER = "micxu@nvidia.com"` in the script to your Atlassian email
- Edit `BASE_URL` if your Confluence instance is at a different URL

---

### Skills

Skills are invokable actions in Claude Code. Use them with `/skill-name` in the Claude Code prompt.

#### snapshot-branch (`/snapshot-branch`)

**Purpose:** Commit current state and create a named branch at that point, then continue on main. Useful for preserving a working version before making breaking changes.

**How it works:**
1. Shows you `git status`
2. Asks for commit message (never auto-generates)
3. Asks for branch name (never auto-generates)
4. Shows exact commands before running
5. Pushes both main and the snapshot branch
6. Tells you how to retrieve the snapshot later

#### spec-interview (`/spec-interview`)

**Purpose:** Interactive interview to create a detailed specification document. Useful when you need to think through requirements before coding.

**How it works:**
1. Asks probing, non-obvious questions about your feature/project
2. Covers technical implementation, UI/UX, tradeoffs, edge cases
3. Keeps interviewing until the picture is complete
4. Writes a comprehensive spec file

**Usage:**
```
/spec-interview build a CLI tool for ROM validation
```

#### verify-telemetry (`/verify-telemetry`)

**Purpose:** Verify that telemetry data (metrics/traces) arrived in Prometheus/Tempo after sending.

**Note:** This skill requires `~/.claude/hooks/verify-telemetry.sh` to be present. That hook script is not included in this repo. If you need it, copy it from your primary machine:
```bash
mkdir -p ~/.claude/hooks
cp /path/to/verify-telemetry.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/verify-telemetry.sh
```

---

### Ghostty Config

**Location:** `~/.config/ghostty/config`
**Purpose:** Terminal emulator configuration for Ghostty.

**Key settings:**
| Setting | Value | Notes |
|---------|-------|-------|
| Font | JetBrainsMono Nerd Font, 14pt | Requires Nerd Font install |
| Theme | Catppuccin Mocha | Dark theme |
| Background | 90% opacity, blur 20 | Translucent with blur |
| Titlebar | Transparent | Clean macOS look |
| Scrollback | 25MB | Generous for long Claude sessions |
| Quick Terminal | Ctrl+\` | Quake-style dropdown from top |
| Window State | Always saved | Restores layout on relaunch |

---

## Ghostty SAND Keybindings

A mnemonic for the four categories of panel operations:

### S -- Split (create new panels)

| Shortcut | Action |
|----------|--------|
| `Cmd+D` | Split right (vertical) |
| `Cmd+Shift+D` | Split down (horizontal) |

### A -- Across (move between tabs)

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New tab |
| `Cmd+Shift+Left` | Previous tab |
| `Cmd+Shift+Right` | Next tab |

### N -- Navigate (jump between splits)

| Shortcut | Action |
|----------|--------|
| `Cmd+Alt+Left` | Focus split to the left |
| `Cmd+Alt+Right` | Focus split to the right |
| `Cmd+Alt+Up` | Focus split above |
| `Cmd+Alt+Down` | Focus split below |
| `Cmd+Shift+E` | Equalize all splits |
| `Cmd+Shift+F` | Zoom/unzoom current split |

### D -- Destroy (close panels)

| Shortcut | Action |
|----------|--------|
| `Cmd+W` | Close current panel/tab |

### Other Useful Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+\`` | Toggle quick terminal (global) |
| `Cmd+Shift+,` | Reload config |
| `Cmd+Shift+P` | Command palette |
| `Cmd+F` | Search scrollback (Ghostty 1.3+) |
| `Cmd+Plus` | Increase font size |
| `Cmd+Minus` | Decrease font size |
| `Cmd+0` | Reset font size |

---

## Customization

### Change the Ghostty theme

Edit `ghostty/config` and change the `theme` line:
```
theme = Catppuccin Mocha       # dark
theme = Catppuccin Latte       # light
theme = light:Catppuccin Latte,dark:Catppuccin Mocha  # auto-switch with system
```
Reload with `Cmd+Shift+,` (no restart needed).

### Change font size

Edit `ghostty/config`:
```
font-size = 16
```

### Change background opacity

Edit `ghostty/config`:
```
background-opacity = 1.0    # fully opaque
background-opacity = 0.85   # more transparent
```

### Change Claude Code model

Edit `claude/settings.json`:
```json
"model": "sonnet"
```
Options: `"opus"`, `"opus[1m]"`, `"sonnet"`, `"haiku"`

### Add more auto-approved permissions

Just use Claude Code normally. When it asks for permission to run a command and you click "Allow", it gets added to `settings.local.json` automatically.

---

## Updating

Since the installer uses symlinks, your live config files point directly into this repo.

**To push changes from this machine:**
```bash
cd ~/claude-code-config   # or wherever you cloned
git add .
git commit -m "update config"
git push
```

**To pull changes on another machine:**
```bash
cd ~/claude-code-config
git pull
# symlinks auto-update -- no re-install needed
```

---

## Uninstall

Remove all symlinks and restore backups:

```bash
# remove symlinks
rm ~/.claude/CLAUDE.md
rm ~/.claude/settings.json
rm ~/.claude/settings.local.json
rm ~/.claude/statusline-command.sh
rm ~/.claude/agents/pdf-to-markdown.md
rm ~/.claude/commands/chrome-js.md
rm ~/.claude/scripts/confluence-update.py
rm ~/.claude/skills/snapshot-branch.md
rm ~/.claude/skills/spec-interview.md
rm ~/.claude/skills/verify-telemetry.md
rm ~/.config/ghostty/config

# restore backups (if they exist)
for f in ~/.claude/*.bak ~/.claude/**/*.bak ~/.config/ghostty/*.bak; do
    [ -f "$f" ] && mv "$f" "${f%.bak}"
done
```

---

## Troubleshooting

### Statusline not showing

1. Check jq is installed: `jq --version`
2. Check the script is linked: `ls -la ~/.claude/statusline-command.sh`
3. Check settings.json has the statusline config:
   ```bash
   cat ~/.claude/settings.json | jq .statusLine
   ```
4. Restart Claude Code

### Ghostty font looks wrong

JetBrains Mono Nerd Font is probably not installed:
```bash
brew install --cask font-jetbrains-mono-nerd-font
```
Then restart Ghostty (or `Cmd+Shift+,` to reload config).

### Quick terminal not working

The `Ctrl+`` shortcut is a global hotkey. If another app captures it first, it won't work. Check System Settings > Keyboard > Keyboard Shortcuts for conflicts.

### Claude Code plugins not found

NVIDIA-specific plugins (`the-village@gfw`, `generate-t5t@gfw`, `nvidia-service-integrations@gfw`) require NVIDIA internal plugin registries. Remove them from `settings.json` if you're not on the NVIDIA network:

```json
"enabledPlugins": {
    "clangd-lsp@claude-plugins-official": true
}
```

### Symlink broken after moving the repo

If you move the cloned repo to a different path, re-run `./install.sh` to recreate the symlinks.

### Permissions accumulating junk

If `settings.local.json` has too many entries, you can reset it:
```bash
# back up current
cp ~/.claude/settings.local.json ~/.claude/settings.local.json.bak

# re-link the clean version from this repo
./install.sh
```
Permissions will re-accumulate as you use Claude Code.
