#!/bin/zsh
# Claude Code hook: emit WezTerm user var for tab state tracking (macOS).
# Usage: claude-state.zsh <running|asking|idle>
#
# Claude Code redirects hook stdout, so /dev/tty is unavailable.
# We walk the process tree via ps to find the ancestor's PTY device.
STATE="$1"

TTY=""
pid=$PPID
while (( pid > 1 )); do
  tty_name=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [[ -n "$tty_name" && "$tty_name" != "??" ]]; then
    TTY="/dev/$tty_name"
    break
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[[ -z "$TTY" ]] && exit 0

ENCODED=$(printf '%s' "$STATE" | base64 | tr -d '\n')
if [[ -n "$TMUX" ]]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
