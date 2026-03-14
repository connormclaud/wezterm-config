local wezterm = require("wezterm")

local M = {}

-- catppuccin mocha palette (single source of truth)
M.base    = "#1e1e2e"
M.surface = "#45475a"
M.overlay = "#6c7086"
M.subtext = "#a6adc8"
M.text    = "#cdd6f4"
M.green   = "#a6e3a1"
M.yellow  = "#f9e2af"
M.blue    = "#89b4fa"
M.peach   = "#fab387"
M.toxic   = "#4AE08C"

-- Powerline glyphs (Nerd Font)
M.SOLID_RIGHT  = "\u{e0b0}"  --
M.SOLID_LEFT   = "\u{e0b2}"  --

-- Claude state icons (Nerd Font)
M.ICON_RUNNING = "\u{f0ea9}" -- 󰚩
M.ICON_ASKING  = "\u{f128}"  --
M.ICON_IDLE    = "\u{f012c}" -- 󰄬

-- Modules register custom per-pane styling via this list.
-- Each fn(tab [, index, title]) returns { bg, fg, icon, bold } or nil to fall through.
local pane_styles = {}

function M.register_pane_style(fn)
  table.insert(pane_styles, fn)
end

function M.setup_tab_title()
  wezterm.on("format-tab-title", function(tab, _tabs, _panes, _cfg, hover)
    local index = tab.tab_index + 1
    local title = tab.tab_title
    if not title or #title == 0 then
      local cwd = tab.active_pane.current_working_dir
      if cwd then
        local path = cwd.file_path or ""
        title = path:match("([^/]+)/?$") or ""
      end
      if not title or #title == 0 then
        title = tab.active_pane.title
      end
    end

    -- Collect style from registered pane_style callbacks
    local style
    for _, fn in ipairs(pane_styles) do
      style = fn(tab, index, title)
      if style then break end
    end

    local bar_bg = M.base
    local icon = (style and style.icon) or ""
    local prefix = icon ~= "" and (icon .. " ") or ""

    if tab.is_active then
      local bg = (style and style.bg) or M.surface
      local fg = (style and style.fg) or M.text
      local content = string.format(" %s%d: %s ", prefix, index, title)

      local elements = {
        -- Left powerline cap
        { Background = { Color = bar_bg } },
        { Foreground = { Color = bg } },
        { Text = M.SOLID_RIGHT },
        -- Content
        { Background = { Color = bg } },
        { Foreground = { Color = fg } },
      }
      if style and style.bold then
        table.insert(elements, { Attribute = { Intensity = "Bold" } })
      end
      table.insert(elements, { Text = content })
      -- Right powerline cap
      table.insert(elements, { Background = { Color = bar_bg } })
      table.insert(elements, { Foreground = { Color = bg } })
      table.insert(elements, { Text = M.SOLID_LEFT })
      return elements
    end

    -- Inactive tab with state — colored text, no pill
    if style then
      local content = string.format(" %s%d: %s ", prefix, index, title)
      local elements = {
        { Background = { Color = bar_bg } },
        { Foreground = { Color = style.bg } },
      }
      if hover then
        table.insert(elements, { Attribute = { Intensity = "Bold" } })
      end
      table.insert(elements, { Text = content })
      return elements
    end

    -- Inactive tab without state
    local fg = M.subtext
    if hover then fg = M.text end
    local unseen = ""
    if tab.active_pane.has_unseen_output then
      fg = M.yellow
      unseen = "\u{25cf} "
    end

    return {
      { Background = { Color = bar_bg } },
      { Foreground = { Color = fg } },
      { Text = string.format(" %s%d: %s ", unseen, index, title) },
    }
  end)
end

return M
