#!/bin/bash
# Claude Code hook: emit WezTerm user var for tab state tracking.
# Usage: claude-state.sh <running|asking|idle>
#
# Claude Code redirects hook stdout to files, so /dev/tty is unavailable.
# We walk the process tree to find the ancestor's PTY device instead.
STATE="$1"

TTY=""
CLAUDE_PID=""
pid=$PPID
while [ "$pid" != "1" ] && [ -n "$pid" ]; do
  fd=$(readlink /proc/$pid/fd/1 2>/dev/null)
  if [[ "$fd" == /dev/pts/* ]] && [ -z "$TTY" ]; then TTY="$fd"; fi
  pname=$(cat /proc/$pid/comm 2>/dev/null)
  if [ -z "$CLAUDE_PID" ] && { [ "$pname" = "node" ] || [ "$pname" = "claude" ]; }; then CLAUDE_PID=$pid; fi
  # Fast path: stop walking once we have everything we need.
  if [ -n "$TTY" ]; then
    if [ "$STATE" != "idle" ] || [ -n "$CLAUDE_PID" ]; then break; fi
  fi
  pid=$(cut -d' ' -f4 /proc/$pid/stat 2>/dev/null)
done
[ -z "$TTY" ] && exit 0

# When Stop fires (idle), check if Claude still has background tasks running.
# Background Bash/Agent tasks are descendant shell processes of the node process.
if [ "$STATE" = "idle" ] && [ -n "$CLAUDE_PID" ]; then
  has_bg_shell() {
    local parent=$1 depth=${2:-0}
    [ "$depth" -gt 3 ] && return 1
    local child cname
    for child in $(pgrep -P "$parent" 2>/dev/null); do
      [ "$child" = "$$" ] && continue
      cname=$(cat /proc/$child/comm 2>/dev/null)
      case "$cname" in
        bash|zsh|sh|fish) return 0 ;;
      esac
      has_bg_shell "$child" $((depth + 1)) && return 0
    done
    return 1
  }
  has_bg_shell "$CLAUDE_PID" && STATE="running"
fi

# Fast path: empty state clears the user var.
if [ -z "$STATE" ]; then ENCODED=""; else ENCODED=$(printf '%s' "$STATE" | base64 -w0); fi
if [ -n "$TMUX" ]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
