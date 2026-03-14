local wezterm = require("wezterm")
local theme = require("theme")

local M = {}

local ESCALATION_SECS = 120

local STATE_COLORS = {
  asking  = theme.peach,
  running = theme.blue,
  idle    = theme.toxic,
}

function M.update_border(window)
  local dominated = "idle"
  local max_elapsed = 0

  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, pane in ipairs(tab:panes()) do
      local state = pane:get_user_vars().claude_state
      if state == "asking" then
        dominated = "asking"
        local key = tostring(pane:pane_id())
        local since = (wezterm.GLOBAL.asking_since or {})[key]
        if since then
          local elapsed = os.time() - since
          if elapsed > max_elapsed then max_elapsed = elapsed end
        end
      elseif state == "running" and dominated ~= "asking" then
        dominated = "running"
      end
    end
  end

  local color = STATE_COLORS[dominated] or theme.toxic
  if dominated == "asking" then
    local t = math.min(max_elapsed / ESCALATION_SECS, 1)
    color = theme.lerp_color(theme.peach, theme.red, t)
  end

  local key = "border_state_" .. tostring(window:window_id())
  local cache_val = dominated .. "_" .. tostring(max_elapsed)
  local prev = (wezterm.GLOBAL.border_states or {})[key]
  if prev == cache_val then return end

  wezterm.GLOBAL.border_states = wezterm.GLOBAL.border_states or {}
  wezterm.GLOBAL.border_states[key] = cache_val

  local overrides = window:get_config_overrides() or {}
  overrides.window_frame = theme.make_window_frame(color)
  window:set_config_overrides(overrides)
end

return M
