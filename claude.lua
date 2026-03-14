local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

local DEBOUNCE_SECS = 2

theme.register_pane_style(function(tab, index, title)
  local state = tab.active_pane.user_vars.claude_state

  -- Debounce: when "idle" arrives shortly after running/asking activity,
  -- keep showing "running" to bridge gaps between background agent hooks.
  if state == "running" or state == "asking" then
    local G = wezterm.GLOBAL
    G.claude_last_active = G.claude_last_active or {}
    G.claude_last_active[tostring(tab.active_pane.pane_id)] =
      tonumber(wezterm.time.now():format("%s"))
  elseif state == "idle" then
    local G = wezterm.GLOBAL
    local last = (G.claude_last_active or {})[tostring(tab.active_pane.pane_id)]
    if last then
      local now = tonumber(wezterm.time.now():format("%s"))
      if now - last < DEBOUNCE_SECS then
        state = "running"
      else
        G.claude_last_active[tostring(tab.active_pane.pane_id)] = nil
      end
    end
  end

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
