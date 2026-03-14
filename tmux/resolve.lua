local wezterm = require("wezterm")
local core = require("tmux.core")

local M = {}

-- Run a tmux command, parse each line with pattern, return all captures from
-- the first line where predicate(captures...) is truthy.
local function tmux_find(args, pattern, predicate)
  local ok, out = wezterm.run_child_process(args)
  if not ok then return nil end
  for line in out:gmatch("[^\n]+") do
    local captures = { line:match(pattern) }
    if #captures > 0 and predicate(table.unpack(captures)) then
      return table.unpack(captures)
    end
  end
end

-- Finds the CC-attached tmux session name.
function M.session()
  if not core.bin then return nil end
  local _, name = tmux_find(
    { core.bin, "list-clients", "-F", "#{client_control_mode}\t#{session_name}" },
    "^(%d+)\t(.+)$",
    function(mode) return mode == "1" end
  )
  return name
end

-- Returns the tmux @window_id for the session's active window (synced by CC).
function M.window()
  local session = M.session()
  if not session then return nil end
  local _, wid = tmux_find(
    { core.bin, "list-windows", "-t", session, "-F", "#{window_active}\t#{window_id}" },
    "^(%d+)\t(.+)$",
    function(active) return active == "1" end
  )
  return wid
end

-- Returns the tmux %pane_id for the active pane in the session's active window.
function M.pane()
  local win = M.window()
  if not win then return nil end
  local _, pid = tmux_find(
    { core.bin, "list-panes", "-t", win, "-F", "#{pane_active}\t#{pane_id}" },
    "^(%d+)\t(.+)$",
    function(active) return active == "1" end
  )
  return pid
end

-- Swap the active tmux window with its neighbor (direction: -1 left, +1 right).
function M.swap_window(direction)
  local session = M.session()
  if not session then return end
  local ok, out = wezterm.run_child_process({
    core.bin, "list-windows", "-t", session,
    "-F", "#{window_id}\t#{window_active}",
  })
  if not ok then return end
  local windows = {}
  local active_idx = nil
  for line in out:gmatch("[^\n]+") do
    local wid, is_active = line:match("^(.+)\t(%d+)$")
    if wid then
      table.insert(windows, wid)
      if is_active == "1" then active_idx = #windows end
    end
  end
  if not active_idx then return end
  local target_idx = active_idx + direction
  if target_idx < 1 or target_idx > #windows then return end
  wezterm.run_child_process({
    core.bin, "swap-window", "-d", "-s", windows[active_idx], "-t", windows[target_idx],
  })
end

return M
