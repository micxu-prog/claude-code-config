#!/usr/bin/env bash
# install.sh -- install claude code config files on a fresh mac
# usage: ./install.sh [--dry-run] [--symlink]
#
# default: copies files (independent, safe to diverge per-machine)
# --symlink: symlinks instead (edits in repo propagate instantly)

set -euo pipefail

# ---- config ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GHOSTTY_DIR="$HOME/.config/ghostty"
DRY_RUN=false
USE_SYMLINK=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --symlink)  USE_SYMLINK=true ;;
    esac
done

if $DRY_RUN; then
    echo "[dry-run] no changes will be made"
    echo ""
fi

# ---- helpers ----
info()  { printf "\033[38;5;39m[info]\033[0m  %s\n" "$1"; }
warn()  { printf "\033[38;5;208m[warn]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[38;5;78m[ok]\033[0m    %s\n" "$1"; }
err()   { printf "\033[38;5;196m[err]\033[0m   %s\n" "$1"; }

install_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        err "source not found: $src"
        return 1
    fi

    # create parent directory if needed
    local dst_dir
    dst_dir="$(dirname "$dst")"
    if [[ ! -d "$dst_dir" ]]; then
        if $DRY_RUN; then
            info "would create directory: $dst_dir"
        else
            mkdir -p "$dst_dir"
            info "created directory: $dst_dir"
        fi
    fi

    # back up existing file (skip if already a symlink to us)
    if [[ -e "$dst" || -L "$dst" ]]; then
        if $USE_SYMLINK; then
            local existing_target
            existing_target="$(readlink "$dst" 2>/dev/null || echo "")"
            if [[ "$existing_target" == "$src" ]]; then
                ok "already linked: $dst"
                return 0
            fi
        fi

        if [[ -L "$dst" ]]; then
            warn "replacing symlink: $dst"
        else
            if $DRY_RUN; then
                info "would back up: $dst -> $dst.bak"
            else
                cp "$dst" "$dst.bak"
                info "backed up: $dst -> $dst.bak"
            fi
        fi
    fi

    if $DRY_RUN; then
        if $USE_SYMLINK; then
            info "would link: $dst -> $src"
        else
            info "would copy: $src -> $dst"
        fi
    else
        if $USE_SYMLINK; then
            ln -sf "$src" "$dst"
            ok "linked: $dst -> $src"
        else
            cp "$src" "$dst"
            ok "copied: $src -> $dst"
        fi
    fi
}

# ---- preflight checks ----
echo "=== claude code config installer ==="
if $USE_SYMLINK; then
    info "mode: symlink (changes in repo propagate instantly)"
else
    info "mode: copy (independent files, safe to customize per-machine)"
fi
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
    err "this installer is for macOS only"
    exit 1
fi

# check prerequisites
missing=()
if ! command -v claude &>/dev/null; then
    missing+=("claude (npm install -g @anthropic-ai/claude-code)")
fi
if ! command -v jq &>/dev/null; then
    missing+=("jq (brew install jq)")
fi
if [[ ! -d "/Applications/Ghostty.app" ]]; then
    missing+=("Ghostty (https://ghostty.org)")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    warn "missing prerequisites (install will continue, but some features won't work):"
    for m in "${missing[@]}"; do
        warn "  - $m"
    done
    echo ""
fi

# ---- install claude config files ----
info "installing claude code config files..."
echo ""

# core config
install_file "$SCRIPT_DIR/claude/CLAUDE.md"              "$CLAUDE_DIR/CLAUDE.md"
install_file "$SCRIPT_DIR/claude/settings.json"           "$CLAUDE_DIR/settings.json"
install_file "$SCRIPT_DIR/claude/settings.local.json"     "$CLAUDE_DIR/settings.local.json"
install_file "$SCRIPT_DIR/claude/statusline-command.sh"   "$CLAUDE_DIR/statusline-command.sh"

# agents
install_file "$SCRIPT_DIR/claude/agents/pdf-to-markdown.md" "$CLAUDE_DIR/agents/pdf-to-markdown.md"

# commands
install_file "$SCRIPT_DIR/claude/commands/chrome-js.md"   "$CLAUDE_DIR/commands/chrome-js.md"

# scripts
install_file "$SCRIPT_DIR/claude/scripts/confluence-update.py" "$CLAUDE_DIR/scripts/confluence-update.py"

# skills
install_file "$SCRIPT_DIR/claude/skills/snapshot-branch.md"   "$CLAUDE_DIR/skills/snapshot-branch.md"
install_file "$SCRIPT_DIR/claude/skills/spec-interview.md"    "$CLAUDE_DIR/skills/spec-interview.md"
install_file "$SCRIPT_DIR/claude/skills/verify-telemetry.md"  "$CLAUDE_DIR/skills/verify-telemetry.md"

echo ""

# ---- install ghostty config ----
info "installing ghostty config..."
echo ""
install_file "$SCRIPT_DIR/ghostty/config" "$GHOSTTY_DIR/config"

echo ""

# ---- font check ----
if ! fc-list 2>/dev/null | grep -qi "jetbrains.*nerd" && \
   ! system_profiler SPFontsDataType 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
    warn "JetBrains Mono Nerd Font not found. install it:"
    warn "  brew install --cask font-jetbrains-mono-nerd-font"
    echo ""
fi

# ---- done ----
echo "=== installation complete ==="
echo ""
info "notes:"
if $USE_SYMLINK; then
    echo "  - edit files in this repo; symlinks propagate changes instantly"
    echo "  - to sync: git pull (symlinks auto-update)"
else
    echo "  - files are independent copies -- edit them directly on this machine"
    echo "  - to pull upstream changes: git pull && ./install.sh"
fi
echo "  - settings.local.json permissions auto-accumulate as you use claude code"
echo "  - confluence-update.py: update USER variable for your email"
echo "  - verify-telemetry skill needs ~/.claude/hooks/verify-telemetry.sh"
