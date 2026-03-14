local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

theme.register_pane_style(function(tab, index, title)
  local state = tab.active_pane.user_vars.claude_state

  if state == "running" then
    return {
      { Foreground = { Color = theme.blue } },
      { Text = string.format(" %d: %s … ", index, title) },
    }
  elseif state == "asking" then
    return {
      { Foreground = { Color = theme.peach } },
      { Attribute = { Intensity = "Bold" } },
      { Text = string.format(" %d: %s ? ", index, title) },
    }
  elseif state == "idle" then
    return {
      { Foreground = { Color = theme.green } },
      { Attribute = { Intensity = "Bold" } },
      { Text = string.format(" %d: %s ✓ ", index, title) },
    }
  end
  return nil
end)

return M
