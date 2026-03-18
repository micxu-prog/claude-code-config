#!/usr/bin/env bash
# statusline for claude code -- compact, colorful, per-section colors

input=$(cat)

# --- data extraction ---
ccver=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
used=$(echo "$input" | jq -r '.context_window.used_percentage // "0"')
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# shorten model name: strip "Claude " prefix if present
model_short=$(echo "$model" | sed 's/^Claude //')

# git branch: skip lock, fallback to empty
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# --- ANSI colors (256-color) ---
reset="\033[0m"
c_ver="\033[38;5;39m"      # bright blue   -- version
c_ctx="\033[38;5;208m"     # orange        -- context %
c_model="\033[38;5;141m"   # soft purple   -- model
c_dir="\033[38;5;78m"      # green         -- directory
c_branch="\033[38;5;220m"  # yellow        -- git branch
c_ay_on="\033[38;5;46m"   # bright green  -- autoyes ON
c_ay_off="\033[38;5;196m" # bright red    -- autoyes OFF
sep="\033[38;5;240m | \033[0m"  # dim gray separator

# --- build line ---
line="${c_ver}V${ccver}${reset}${sep}"
line+="${c_ctx}Context: ${used}%${reset}${sep}"
line+="${c_model}(${model_short})${reset}${sep}"
line+="${c_dir}Dir: ${cwd}${reset}"

if [ -n "$git_branch" ]; then
  line+="${sep}${c_branch}Branch: ${git_branch}${reset}"
fi

# autoyes state (only show if state file exists and process is alive)
ay_state_file="$HOME/.autoyes/state"
if [ -f "$ay_state_file" ]; then
  ay_state=$(head -1 "$ay_state_file" 2>/dev/null)
  ay_pid=$(tail -1 "$ay_state_file" 2>/dev/null)
  # only show if autoyes process is still running, otherwise clean up stale file
  if [ -n "$ay_pid" ] && kill -0 "$ay_pid" 2>/dev/null; then
    if [ "$ay_state" = "ON" ]; then
      line+="${sep}${c_ay_on}AutoYes: ON${reset}"
    else
      line+="${sep}${c_ay_off}AutoYes: OFF${reset}"
    fi
  else
    rm -f "$ay_state_file"
  fi
fi

printf "%b\n" "$line"
