local wezterm = require("wezterm")
local tmux = require("tmux")

local M = {}

function M.keys()
  local act = wezterm.action
  return {
    -- Split panes
    { key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    -- Kill current pane (no confirm, for killing hung processes)
    { key = "K", mods = "CTRL|SHIFT", action = tmux.kill_pane_action() },
    -- Quick pane selection overlay with numeric labels
    { key = "o", mods = "CTRL|SHIFT", action = act.PaneSelect({ alphabet = "1234567890" }) },
    -- Shift+Enter: send CSI u sequence explicitly so it survives tmux
    { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b[13;2u") },
    -- Rename current tab / tmux window (F2 = universal rename key)
    { key = "F2", action = tmux.rename_tab_action() },
    -- Move tab left/right (syncs tmux CC window order)
    { key = "PageUp", mods = "CTRL|SHIFT", action = tmux.move_tab_action(-1) },
    { key = "PageDown", mods = "CTRL|SHIFT", action = tmux.move_tab_action(1) },
  }
end

return M
