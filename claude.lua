local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

local ESCALATION_SECS = 120

-- Track when each pane enters "asking" state
wezterm.on("user-var-changed", function(_window, pane, name, value)
  if name ~= "claude_state" then return end
  wezterm.GLOBAL.asking_since = wezterm.GLOBAL.asking_since or {}
  local key = tostring(pane:pane_id())
  if value == "asking" then
    if not wezterm.GLOBAL.asking_since[key] then
      wezterm.GLOBAL.asking_since[key] = os.time()
    end
  else
    wezterm.GLOBAL.asking_since[key] = nil
  end
end)

theme.register_pane_style(function(tab)
  local state = tab.active_pane.user_vars.claude_state

  if state == "running" then
    return { bg = theme.blue, fg = theme.base, icon = theme.ICON_RUNNING }
  elseif state == "asking" then
    local key = tostring(tab.active_pane.pane_id)
    local since = (wezterm.GLOBAL.asking_since or {})[key]
    local t = 0
    if since then
      t = math.min((os.time() - since) / ESCALATION_SECS, 1)
    end
    local bg = theme.lerp_color(theme.peach, theme.red, t)
    return { bg = bg, fg = theme.base, icon = theme.ICON_ASKING, bold = true }
  elseif state == "idle" then
    return { bg = theme.green, fg = theme.base, icon = theme.ICON_IDLE, bold = true }
  end
end)

return M
