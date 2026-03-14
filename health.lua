local wezterm = require("wezterm")

local M = {}

local interval_seconds = 20 * 60
local enabled = true

local theme = require("theme")

function M.update_right_status(window)
  if enabled then
    local now = tonumber(wezterm.time.now():format("%s"))
    local cycle = now % interval_seconds
    if cycle < 25 then
      local remaining = 25 - cycle
      local msg = string.format(" \u{f06e} Look away ~6m for %ds ", remaining)
      window:set_right_status(wezterm.format({
        { Foreground = { Color = theme.base } },
        { Background = { Color = theme.yellow } },
        { Attribute = { Intensity = "Bold" } },
        { Text = msg },
      }))
    else
      window:set_right_status(wezterm.format({
        { Foreground = { Color = theme.subtext } },
        { Text = " \u{f0f3} " },
      }))
    end
  else
    window:set_right_status(wezterm.format({
      { Foreground = { Color = theme.subtext } },
      { Text = " \u{f1f6} " },
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
