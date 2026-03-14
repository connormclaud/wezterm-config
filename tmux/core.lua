local wezterm = require("wezterm")

local M = {}

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

return M
