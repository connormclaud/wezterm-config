local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

theme.register_pane_style(function(tab)
  local state = tab.active_pane.user_vars.claude_state

  if state == "running" then
    return { bg = theme.blue, fg = theme.base, icon = theme.ICON_RUNNING }
  elseif state == "asking" then
    return { bg = theme.peach, fg = theme.base, icon = theme.ICON_ASKING, bold = true }
  elseif state == "idle" then
    return { bg = theme.green, fg = theme.base, icon = theme.ICON_IDLE, bold = true }
  end
end)

return M
