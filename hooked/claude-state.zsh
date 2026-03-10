#!/bin/zsh
# Claude Code hook: emit WezTerm user var for tab state tracking (macOS).
# Usage: claude-state.zsh <running|asking|idle>
#
# Claude Code redirects hook stdout, so /dev/tty is unavailable.
# We walk the process tree via ps to find the ancestor's PTY device.
STATE="$1"

TTY=""
CLAUDE_PID=""
pid=$PPID
while (( pid > 1 )); do
  info=$(ps -o tty=,ucomm=,ppid= -p "$pid" 2>/dev/null)
  tty_name=${${(z)info}[1]}
  pname=${${(z)info}[2]}
  next_pid=${${(z)info}[3]}

  if [[ -z "$TTY" && -n "$tty_name" && "$tty_name" != "??" ]]; then
    TTY="/dev/$tty_name"
  fi
  if [[ -z "$CLAUDE_PID" && ( "$pname" == "node" || "$pname" == "claude" ) ]]; then
    CLAUDE_PID=$pid
  fi

  # Fast path: stop walking once we have everything we need.
  [[ -n "$TTY" && ( "$STATE" != "idle" || -n "$CLAUDE_PID" ) ]] && break
  pid=$next_pid
done
[[ -z "$TTY" ]] && exit 0

# When Stop fires (idle), check if Claude still has background tasks running.
# Background Bash/Agent tasks are descendant shell processes of the node process.
if [[ "$STATE" == "idle" && -n "$CLAUDE_PID" ]]; then
  # Collect hook's own process chain to exclude from background detection.
  # On Linux, sh(dash) -c doesn't exec-optimize, leaving a wrapper shell
  # that would be falsely detected as a background task.
  HOOK_CHAIN=" $$ "
  _hpid=$PPID
  while (( _hpid > 1 )) && [[ "$_hpid" != "$CLAUDE_PID" ]]; do
    HOOK_CHAIN="${HOOK_CHAIN}${_hpid} "
    _hpid=$(ps -o ppid= -p "$_hpid" 2>/dev/null | tr -d ' ')
  done

  has_bg_shell() {
    local parent=$1 depth=${2:-0}
    (( depth > 3 )) && return 1
    local child cname
    for child in $(pgrep -P "$parent" 2>/dev/null); do
      [[ "$HOOK_CHAIN" == *" $child "* ]] && continue
      cname=$(ps -o ucomm= -p "$child" 2>/dev/null | tr -d ' ')
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
[[ -z "$STATE" ]] && ENCODED="" || ENCODED=$(printf '%s' "$STATE" | base64 | tr -d '\n')
if [[ -n "$TMUX" ]]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
else
  printf '\033]1337;SetUserVar=%s=%s\007' \
    claude_state "$ENCODED" > "$TTY" 2>/dev/null
fi
