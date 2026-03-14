local wezterm = require("wezterm")
local act = wezterm.action
local core = require("tmux.core")
local resolve = require("tmux.resolve")

local M = {}

-- Action: kill current pane, handling tmux CC and local tmux (#4317 workaround)
function M.kill_pane_action()
  return wezterm.action_callback(function(window, pane)
    if core.bin and core.detect(pane) then
      if core.is_cc(pane) then
        local target = resolve.pane()
        if target then
          wezterm.run_child_process({ core.bin, "kill-pane", "-t", target })
        end
        return
      end
      local tty = pane:get_tty_name()
      if tty then
        wezterm.run_child_process({ core.bin, "detach-client", "-t", tty })
      end
    end
    window:perform_action(act.CloseCurrentPane({ confirm = false }), pane)
  end)
end

-- Action: rename tab / tmux window (prompts for name, pre-fills current)
function M.rename_tab_action()
  return wezterm.action_callback(function(window, pane)
    local current = window:active_tab():get_title()
    window:perform_action(
      act.PromptInputLine({
        description = "Rename tab",
        initial_value = current,
        action = wezterm.action_callback(function(inner_window, inner_pane, line)
          if line then
            if core.is_cc(inner_pane) and core.bin then
              local target = resolve.window()
              if target then
                wezterm.run_child_process({ core.bin, "rename-window", "-t", target, line })
              end
            else
              inner_window:active_tab():set_title(line)
            end
          end
        end),
      }),
      pane
    )
  end)
end

-- Action: move tab left/right, syncing tmux CC window order
function M.move_tab_action(direction)
  return wezterm.action_callback(function(window, pane)
    if core.is_cc(pane) then
      resolve.swap_window(direction)
    end
    window:perform_action(act.MoveTabRelative(direction), pane)
  end)
end

return M
