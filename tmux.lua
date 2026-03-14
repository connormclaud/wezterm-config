local wezterm = require("wezterm")
local act = wezterm.action
local theme = require("theme")

local M = {}

-- Detection -----------------------------------------------------------------

-- Resolve tmux binary path once at config load.
-- run_child_process yields across C-call boundary at require time, so use
-- io.popen (synchronous) first, then wezterm.glob for Homebrew fallback.
M.bin = (function()
  local handle = io.popen("command -v tmux 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    local p = result and result:match("^%s*(.-)%s*$")
    if p and #p > 0 then return p end
  end
  for _, g in ipairs(wezterm.glob("/opt/homebrew/bin/tmux")) do return g end
  for _, g in ipairs(wezterm.glob("/usr/local/bin/tmux")) do return g end
  return nil
end)()

function M.detect(pane)
  local domain = pane:get_domain_name()
  if domain == "tmux" then
    return true
  end
  local proc = pane:get_foreground_process_name()
  if proc and proc:match("tmux") then
    return true
  end
  return false
end

-- Returns true only for tmux CC domain panes, not local panes running tmux.
function M.is_cc(pane)
  return pane:get_domain_name() == "tmux"
end

-- Resolution ----------------------------------------------------------------

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
function M.resolve_session()
  if not M.bin then return nil end
  local _, name = tmux_find(
    { M.bin, "list-clients", "-F", "#{client_control_mode}\t#{session_name}" },
    "^(%d+)\t(.+)$",
    function(mode) return mode == "1" end
  )
  return name
end

-- Returns the tmux @window_id for the session's active window (synced by CC).
function M.resolve_window()
  local session = M.resolve_session()
  if not session then return nil end
  local _, wid = tmux_find(
    { M.bin, "list-windows", "-t", session, "-F", "#{window_active}\t#{window_id}" },
    "^(%d+)\t(.+)$",
    function(active) return active == "1" end
  )
  return wid
end

-- Returns the tmux %pane_id for the active pane in the session's active window.
function M.resolve_pane()
  local win = M.resolve_window()
  if not win then return nil end
  local _, pid = tmux_find(
    { M.bin, "list-panes", "-t", win, "-F", "#{pane_active}\t#{pane_id}" },
    "^(%d+)\t(.+)$",
    function(active) return active == "1" end
  )
  return pid
end

-- Actions -------------------------------------------------------------------

-- Swap the active tmux window with its neighbor (direction: -1 left, +1 right).
function M.swap_window(direction)
  local session = M.resolve_session()
  if not session then return end
  local ok, out = wezterm.run_child_process({
    M.bin, "list-windows", "-t", session,
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
    M.bin, "swap-window", "-d", "-s", windows[active_idx], "-t", windows[target_idx],
  })
end

-- Action: kill current pane, handling tmux CC and local tmux (#4317 workaround)
function M.kill_pane_action()
  return wezterm.action_callback(function(window, pane)
    if M.bin and M.detect(pane) then
      if M.is_cc(pane) then
        local target = M.resolve_pane()
        if target then
          wezterm.run_child_process({ M.bin, "kill-pane", "-t", target })
        end
        return
      end
      local tty = pane:get_tty_name()
      if tty then
        wezterm.run_child_process({ M.bin, "detach-client", "-t", tty })
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
            if M.is_cc(inner_pane) and M.bin then
              local target = M.resolve_window()
              if target then
                wezterm.run_child_process({ M.bin, "rename-window", "-t", target, line })
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
    if M.is_cc(pane) then
      M.swap_window(direction)
    end
    window:perform_action(act.MoveTabRelative(direction), pane)
  end)
end

-- Status --------------------------------------------------------------------

function M.update_left_status(window, pane)
  if M.detect(pane) then
    window:set_left_status(wezterm.format({
      { Foreground = { Color = theme.green } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " [tmux]" },
      "ResetAttributes",
      { Foreground = { Color = theme.subtext } },
      { Text = " F1:help" },
    }))
  else
    local proc = pane:get_foreground_process_name() or ""
    local shell = proc:match("([^/]+)$") or "shell"
    window:set_left_status(wezterm.format({
      { Foreground = { Color = theme.subtext } },
      { Text = string.format(" [%s]", shell) },
    }))
  end
end

function M.keys()
  return {
    {
      key = "a",
      mods = "CTRL|SHIFT",
      action = wezterm.action_callback(function(window, pane)
        if not M.bin then
          window:perform_action(
            act.InputSelector({
              title = "Attach tmux session",
              choices = { { id = "", label = "tmux not found" } },
              action = wezterm.action_callback(function() end),
            }),
            pane
          )
          return
        end
        local success, stdout = wezterm.run_child_process({
          M.bin, "list-sessions", "-F",
          "#{session_name}|#{session_windows} wins, created #{t:session_created}",
        })
        local choices = {}
        if success then
          for line in stdout:gmatch("[^\r\n]+") do
            local name = line:match("^([^|]+)")
            table.insert(choices, { id = name, label = line:gsub("|", " — ") })
          end
        end
        if #choices == 0 then
          table.insert(choices, { id = "", label = "No tmux sessions found" })
        end
        window:perform_action(
          act.InputSelector({
            title = "Attach tmux session",
            choices = choices,
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
              if id and id ~= "" then
                inner_window:perform_action(
                  act.SpawnCommandInNewTab({
                    domain = { DomainName = "local" },
                    args = { M.bin, "-CC", "attach", "-t", id },
                  }),
                  inner_pane
                )
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
