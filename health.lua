local wezterm = require("wezterm")

local M = {}

local interval_seconds = 20 * 60
local enabled = true

-- catppuccin mocha
local col_subtext = "#a6adc8"
local col_yellow  = "#f9e2af"

function M.update_right_status(window)
  if enabled then
    local now = tonumber(wezterm.time.now():format("%s"))
    local cycle = now % interval_seconds
    if cycle < 25 then
      local remaining = 25 - cycle
      local msg = string.format(" ⚠ Look away ~6m for %ds ", remaining)
      window:set_right_status(wezterm.format({
        { Foreground = { Color = "#1e1e2e" } },
        { Background = { Color = col_yellow } },
        { Attribute = { Intensity = "Bold" } },
        { Text = msg },
      }))
    else
      window:set_right_status(wezterm.format({
        { Foreground = { Color = col_subtext } },
        { Text = " 🔔 " },
      }))
    end
  else
    window:set_right_status(wezterm.format({
      { Foreground = { Color = col_subtext } },
      { Text = " 🔕 " },
    }))
  end
end

function M.keys()
  return {
    {
      key = "h",
      mods = "CTRL|SHIFT",
      action = wezterm.action_callback(function()
        enabled = not enabled
      end),
    },
  }
end

return M
