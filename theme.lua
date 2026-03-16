local wezterm = require("wezterm")

local M = {}

-- catppuccin mocha palette (single source of truth)
M.base    = "#1e1e2e"
M.mantle  = "#181825"
M.surface = "#45475a"
M.overlay = "#6c7086"
M.subtext = "#a6adc8"
M.text    = "#cdd6f4"
M.green   = "#a6e3a1"
M.yellow  = "#f9e2af"
M.blue    = "#89b4fa"
M.peach   = "#fab387"
M.red     = "#f38ba8"
M.toxic   = "#4AE08C"

-- Powerline glyphs (Nerd Font)
M.SOLID_RIGHT  = "\u{e0b0}"  --
M.SOLID_LEFT   = "\u{e0b2}"  --

-- Claude state icons (Nerd Font)
M.ICON_RUNNING = "\u{f0ea9}" -- 󰚩
M.ICON_ASKING  = "\u{f128}"  --
M.ICON_IDLE    = "\u{f012c}" -- 󰄬

-- Status bar icons (Nerd Font)
M.ICON_TERMINAL = "\u{f489}"  --  (nf-md-console)
M.ICON_PANES    = "\u{f07a5}" -- 󰞥 (nf-md-dock_window)
M.ICON_ZOOM     = "\u{f065}"  --  (nf-fa-expand)

-- Window frame factory (single source of truth for border structure)
function M.make_window_frame(color)
  return {
    border_left_width    = "1px",
    border_right_width   = "1px",
    border_top_height    = "1px",
    border_bottom_height = "1px",
    border_left_color    = color,
    border_right_color   = color,
    border_top_color     = color,
    border_bottom_color  = color,
    active_titlebar_bg   = M.base,
    inactive_titlebar_bg = M.base,
  }
end

-- Linear interpolation between two #rrggbb hex colors; t clamped to 0–1
function M.lerp_color(c1, c2, t)
  t = math.max(0, math.min(1, t))
  local r1, g1, b1 = tonumber(c1:sub(2, 3), 16), tonumber(c1:sub(4, 5), 16), tonumber(c1:sub(6, 7), 16)
  local r2, g2, b2 = tonumber(c2:sub(2, 3), 16), tonumber(c2:sub(4, 5), 16), tonumber(c2:sub(6, 7), 16)
  local r = math.floor(r1 + (r2 - r1) * t + 0.5)
  local g = math.floor(g1 + (g2 - g1) * t + 0.5)
  local b = math.floor(b1 + (b2 - b1) * t + 0.5)
  return string.format("#%02x%02x%02x", r, g, b)
end

-- Modules register custom per-pane styling via this list.
-- Each fn(tab [, index, title]) returns { bg, fg, icon, bold } or nil to fall through.
local pane_styles = {}

function M.register_pane_style(fn)
  table.insert(pane_styles, fn)
end

local function resolve_tab_title(tab)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  end

  local cwd = tab.active_pane.current_working_dir
  if cwd then
    local path = cwd.file_path or ""
    local basename = path:match("([^/]+)/?$")
    if basename and #basename > 0 then
      return basename
    end
  end

  return tab.active_pane.title
end

local function resolve_style(tab, index, title)
  for _, fn in ipairs(pane_styles) do
    local style = fn(tab, index, title)
    if style then
      return style
    end
  end
  return nil
end

local function collect_badges(tab, style)
  local badges = {}
  local icon = (style and style.icon) or ""
  local has_state_icon = icon ~= ""

  -- Claude/agent panes can have persistent unseen output; prioritize state badge there.
  if tab.active_pane.has_unseen_output and not has_state_icon then
    table.insert(badges, { text = "\u{25cf}", fg = M.yellow })
  end

  if has_state_icon then
    local icon_fg
    if tab.is_active then
      icon_fg = (style and style.fg) or M.text
    else
      icon_fg = (style and style.bg) or M.subtext
      -- Keep state color visible while making inactive tabs feel less "active".
      icon_fg = M.lerp_color(icon_fg, M.subtext, 0.35)
    end
    table.insert(badges, { text = icon, fg = icon_fg })
  end

  return badges
end

local function append_badges(elements, badges)
  for _, badge in ipairs(badges) do
    table.insert(elements, { Foreground = { Color = badge.fg } })
    table.insert(elements, { Text = badge.text .. " " })
  end
end

local function active_tab_elements(tab, style, bar_bg, index, title)
  local bg = (style and style.bg) or M.surface
  local fg = (style and style.fg) or M.text
  local badges = collect_badges(tab, style)

  local elements = {
    { Background = { Color = bar_bg } },
    { Foreground = { Color = bg } },
    { Text = M.SOLID_RIGHT },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = " " },
  }

  append_badges(elements, badges)
  table.insert(elements, { Foreground = { Color = fg } })

  if style and style.bold then
    table.insert(elements, { Attribute = { Intensity = "Bold" } })
  end

  table.insert(elements, { Text = string.format("%d: %s ", index, title) })

  if style and style.bold then
    table.insert(elements, { Attribute = { Intensity = "Normal" } })
  end

  table.insert(elements, { Background = { Color = bar_bg } })
  table.insert(elements, { Foreground = { Color = bg } })
  table.insert(elements, { Text = M.SOLID_LEFT })
  return elements
end

local function inactive_tab_elements(tab, style, bar_bg, index, title, hover)
  local badges = collect_badges(tab, style)
  local text_fg = hover and M.text or M.subtext

  local elements = {
    { Background = { Color = bar_bg } },
    { Foreground = { Color = text_fg } },
    { Text = " " },
  }

  append_badges(elements, badges)
  table.insert(elements, { Foreground = { Color = text_fg } })

  if hover then
    table.insert(elements, { Attribute = { Intensity = "Bold" } })
  end

  table.insert(elements, { Text = string.format("%d: %s ", index, title) })

  if hover then
    table.insert(elements, { Attribute = { Intensity = "Normal" } })
  end

  return elements
end

local CONTROL_TAB_ELEMENTS = {
  { Background = { Color = M.base } },
  { Foreground = { Color = M.overlay } },
  { Text = " " .. M.ICON_TERMINAL .. " " },
}

function M.setup_tab_title()
  wezterm.on("format-tab-title", function(tab, _tabs, _panes, _cfg, hover)
    if tab.active_pane.user_vars.tmux_cc_control == "true" then
      return CONTROL_TAB_ELEMENTS
    end

    local index = tab.tab_index + 1
    local title = resolve_tab_title(tab)
    local style = resolve_style(tab, index, title)
    local bar_bg = M.base

    if tab.is_active then
      return active_tab_elements(tab, style, bar_bg, index, title)
    end

    return inactive_tab_elements(tab, style, bar_bg, index, title, hover)
  end)
end

return M
