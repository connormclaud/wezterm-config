#!/bin/bash
# Claude Code hook: emit WezTerm user var for tab state tracking.
# Usage: claude-state.sh [running|asking|idle]
# No argument clears the state (SessionEnd).
#
# Claude Code redirects hook stdout, so we walk /proc to find the
# ancestor PTY and write the OSC escape directly.
STATE="$1"

# Walk up the process tree to find the first ancestor with a PTY on stdout.
TTY=""
pid=$PPID
while [ "$pid" != "1" ] && [ -n "$pid" ]; do
  fd=$(readlink /proc/$pid/fd/1 2>/dev/null)
  if [[ "$fd" == /dev/pts/* ]]; then TTY="$fd"; break; fi
  pid=$(cut -d' ' -f4 /proc/$pid/stat 2>/dev/null)
done
[ -z "$TTY" ] && exit 0

# Encode state as base64 (empty state -> empty value to clear the var).
if [ -n "$STATE" ]; then ENCODED=$(printf '%s' "$STATE" | base64 -w0); else ENCODED=""; fi

# Emit OSC 1337 SetUserVar, with tmux DCS passthrough if needed.
if [ -n "$TMUX" ]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
