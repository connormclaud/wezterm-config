# WezTerm shell integration for Claude Code state tracking
#
# Source this from ~/.zshrc:
#   source ~/.config/wezterm/shell-integration.zsh
#
# Sets the WezTerm user var `claude_state` to "running" when Claude starts
# and "idle" when it exits. The format-tab-title handler in wezterm.lua
# reads this to show a bold green ✓ on tabs where Claude finished.
#
# In tmux, requires: set -g allow-passthrough on
# In tmux -CC (WezTerm control mode), passthrough works automatically.

__wezterm_set_user_var() {
  printf "\033]1337;SetUserVar=%s=%s\007" "$1" "$(echo -n "$2" | base64)"
}

claude() {
  __wezterm_set_user_var claude_state running
  command claude "$@"
  __wezterm_set_user_var claude_state idle
}
