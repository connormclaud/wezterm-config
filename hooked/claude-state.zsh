#!/bin/zsh
# Shared Claude Code / Codex hook: emit WezTerm user var for tab state tracking (macOS).
# Usage: claude-state.zsh [running|asking|idle]
# No argument clears the state (Claude SessionEnd or Codex shell wrapper).
#
# Claude Code redirects hook stdout, so we walk the process tree
# via ps to find the ancestor PTY and write the OSC escape directly.
STATE="$1"

# Walk up the process tree to find the first ancestor with a PTY.
TTY=""
pid=$PPID
while (( pid > 1 )); do
  info=$(ps -o tty=,ppid= -p "$pid" 2>/dev/null)
  tty_name=${${(z)info}[1]}
  next_pid=${${(z)info}[2]}
  if [[ -n "$tty_name" && "$tty_name" != "??" ]]; then
    TTY="/dev/$tty_name"
    break
  fi
  pid=$next_pid
done
[[ -z "$TTY" ]] && exit 0

# Encode state as base64 (empty state -> empty value to clear the var).
[[ -n "$STATE" ]] && ENCODED=$(printf '%s' "$STATE" | base64 | tr -d '\n') || ENCODED=""

# Emit OSC 1337 SetUserVar, with tmux DCS passthrough if needed.
if [[ -n "$TMUX" ]]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
