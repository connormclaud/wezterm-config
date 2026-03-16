local wezterm = require("wezterm")
local theme = require("theme")

local STATE_COLORS = {
  asking  = theme.peach,
  running = theme.blue,
  idle    = theme.toxic,
}

-- Reactive: recompute border only when a pane's claude_state changes.
-- Iterating panes via IPC is expensive on macOS (~6-32ms), so we avoid
-- doing it on every update-status tick and only run on user-var-changed.
wezterm.on("user-var-changed", function(window, pane, name, _value)
  if name ~= "claude_state" then return end

  local dominated = "idle"
  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, p in ipairs(tab:panes()) do
      local state = p:get_user_vars().claude_state
      if state == "asking" then
        dominated = "asking"
        break
      elseif state == "running" and dominated ~= "asking" then
        dominated = "running"
      end
    end
    if dominated == "asking" then break end
  end

  local key = "border_state_" .. tostring(window:window_id())
  local prev = (wezterm.GLOBAL.border_states or {})[key]
  if prev == dominated then return end

  wezterm.GLOBAL.border_states = wezterm.GLOBAL.border_states or {}
  wezterm.GLOBAL.border_states[key] = dominated

  local overrides = window:get_config_overrides() or {}
  overrides.window_frame = theme.make_window_frame(STATE_COLORS[dominated] or theme.toxic)
  window:set_config_overrides(overrides)
end)

return {}
