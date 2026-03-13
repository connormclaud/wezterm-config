local wezterm = require("wezterm")
local tmux = require("tmux")

local M = {}

function M.keys()
  local act = wezterm.action
  return {
    -- Split panes
    {
      key = "d",
      mods = "CTRL|SHIFT",
      action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    {
      key = "e",
      mods = "CTRL|SHIFT",
      action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    -- Kill current pane (no confirm, for killing hung processes)
    {
      key = "K",
      mods = "CTRL|SHIFT",
      action = wezterm.action_callback(function(window, pane)
        if tmux.is_cc(pane) and tmux.bin then
          local target = tmux.resolve_pane()
          if target then
            wezterm.run_child_process({ tmux.bin, "kill-pane", "-t", target })
          end
        else
          window:perform_action(
            act.CloseCurrentPane({ confirm = false }),
            pane
          )
        end
      end),
    },
    -- Quick pane selection overlay with numeric labels
    {
      key = "o",
      mods = "CTRL|SHIFT",
      action = act.PaneSelect({ alphabet = "1234567890" }),
    },
    -- Shift+Enter: send CSI u sequence explicitly so it survives tmux
    {
      key = "Enter",
      mods = "SHIFT",
      action = act.SendString("\x1b[13;2u"),
    },
    -- Rename current tab / tmux window (F2 = universal rename key)
    {
      key = "F2",
      action = wezterm.action_callback(function(window, pane)
        local current = window:active_tab():get_title()
        window:perform_action(
          act.PromptInputLine({
            description = "Rename tab",
            initial_value = current,
            action = wezterm.action_callback(function(inner_window, inner_pane, line)
              if line then
                if tmux.is_cc(inner_pane) and tmux.bin then
                  local target = tmux.resolve_window()
                  if target then
                    wezterm.run_child_process({ tmux.bin, "rename-window", "-t", target, line })
                  end
                else
                  inner_window:active_tab():set_title(line)
                end
              end
            end),
          }),
          pane
        )
      end),
    },
  }
end

return M
