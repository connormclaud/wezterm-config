local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

function M.style_for_state(state)
  if state == "running" then
    return { bg = theme.blue, fg = theme.base, icon = theme.ICON_RUNNING }
  elseif state == "asking" then
    return { bg = theme.peach, fg = theme.base, icon = theme.ICON_ASKING, bold = true }
  elseif state == "idle" then
    return { bg = theme.green, fg = theme.base, icon = theme.ICON_IDLE, bold = true }
  end
end

theme.register_pane_style(function(tab)
  return M.style_for_state(tab.active_pane.user_vars.claude_state)
end)

-- WORKAROUND: Reset kitty keyboard protocol when Claude Code exits.
-- Claude pushes the protocol multiple times and sometimes fails to pop on exit,
-- leaving the terminal in enhanced keyboard mode (anthropics/claude-code#38761).
-- Remove when fixed upstream.
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "claude_state" and value == "" then
    pane:inject_output("\x1b[=0u\x1b[<99u")
  end
end)

return M
