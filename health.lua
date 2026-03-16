local wezterm = require("wezterm")

local M = {}

local interval_seconds = 20 * 60
local enabled = true

local theme = require("theme")

function M.update_right_status(window, pane)
  local bar_bg = theme.base
  local elements = {}

  -- Pane title (e.g. "⏳ Claude Code" set via OSC 0)
  if pane then
    local title = pane:get_title()
    if title and #title > 0 then
      table.insert(elements, { Background = { Color = bar_bg } })
      table.insert(elements, { Foreground = { Color = theme.overlay } })
      table.insert(elements, { Text = title .. "  " })
    end
  end

  -- Pane info: count + zoom state (single API call instead of panes() + panes_with_info())
  local tab = window:active_tab()
  local panes_info = tab and tab:panes_with_info() or {}
  local pane_count = #panes_info
  local is_zoomed = false
  for _, p in ipairs(panes_info) do
    if p.is_zoomed then
      is_zoomed = true
      break
    end
  end

  if pane_count > 1 then
    local pane_bg = is_zoomed and theme.peach or theme.surface
    local pane_fg = is_zoomed and theme.base or theme.subtext
    local zoom_suffix = is_zoomed and (" " .. theme.ICON_ZOOM) or ""
    -- Left powerline cap
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = pane_bg } })
    table.insert(elements, { Text = theme.SOLID_LEFT })
    -- Pill content
    table.insert(elements, { Background = { Color = pane_bg } })
    table.insert(elements, { Foreground = { Color = pane_fg } })
    table.insert(elements, { Text = string.format(" %s %d%s ", theme.ICON_PANES, pane_count, zoom_suffix) })
  end

  -- Health status
  if enabled then
    local now = tonumber(wezterm.time.now():format("%s"))
    local cycle = now % interval_seconds
    if cycle < 25 then
      local remaining = 25 - cycle
      -- Yellow pill with left powerline cap
      table.insert(elements, { Background = { Color = bar_bg } })
      table.insert(elements, { Foreground = { Color = theme.yellow } })
      table.insert(elements, { Text = theme.SOLID_LEFT })
      table.insert(elements, { Background = { Color = theme.yellow } })
      table.insert(elements, { Foreground = { Color = theme.base } })
      table.insert(elements, { Attribute = { Intensity = "Bold" } })
      table.insert(elements, { Text = string.format(" \u{f06e} Look away ~6m for %ds ", remaining) })
    else
      -- Idle: flat bell icon
      table.insert(elements, { Background = { Color = bar_bg } })
      table.insert(elements, { Foreground = { Color = theme.subtext } })
      table.insert(elements, { Text = " \u{f0f3} " })
    end
  else
    -- Disabled: bell-slash icon
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = theme.subtext } })
    table.insert(elements, { Text = " \u{f1f6} " })
  end

  window:set_right_status(wezterm.format(elements))
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
