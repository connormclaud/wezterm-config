#!/bin/bash
# Claude Code hook: emit WezTerm user var for tab state tracking.
# Usage: claude-state.sh <running|asking|idle>
#
# Claude Code redirects hook stdout to files, so /dev/tty is unavailable.
# We walk the process tree to find the ancestor's PTY device instead.
STATE="$1"

TTY=""
pid=$PPID
while [ "$pid" != "1" ] && [ -n "$pid" ]; do
  fd=$(readlink /proc/$pid/fd/1 2>/dev/null)
  if [[ "$fd" == /dev/pts/* ]]; then TTY="$fd"; break; fi
  pid=$(cut -d' ' -f4 /proc/$pid/stat 2>/dev/null)
done
[ -z "$TTY" ] && exit 0

# Fast path: empty state clears the user var.
if [ -z "$STATE" ]; then ENCODED=""; else ENCODED=$(printf '%s' "$STATE" | base64 -w0); fi
if [ -n "$TMUX" ]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
