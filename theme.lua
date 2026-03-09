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

-- Modules register custom per-pane styling via this list.
-- Each fn(tab, index, title) returns formatted elements or nil to fall through.
local pane_styles = {}

function M.register_pane_style(fn)
  table.insert(pane_styles, fn)
end

function M.setup_tab_title()
  wezterm.on("format-tab-title", function(tab)
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

    if tab.is_active then
      for _, fn in ipairs(pane_styles) do
        local result = fn(tab, index, title)
        if result then
          table.insert(result, 1, { Background = { Color = M.surface } })
          return result
        end
      end
      return {
        { Background = { Color = M.surface } },
        { Foreground = { Color = M.text } },
        { Text = string.format(" %d: %s ", index, title) },
      }
    end

    for _, fn in ipairs(pane_styles) do
      local result = fn(tab, index, title)
      if result then return result end
    end

    if tab.active_pane.has_unseen_output then
      return {
        { Foreground = { Color = M.yellow } },
        { Text = string.format(" %d: %s • ", index, title) },
      }
    else
      return {
        { Foreground = { Color = M.overlay } },
        { Text = string.format(" %d: %s ", index, title) },
      }
    end
  end)
end

function M.keys()
  return {}
end

return M
