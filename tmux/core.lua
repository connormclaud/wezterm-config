local wezterm = require("wezterm")

local M = {}

local TMUX_DOMAIN_NAME = "tmux"
local HOMEBREW_TMUX_PATHS = {
  "/opt/homebrew/bin/tmux",
  "/usr/local/bin/tmux",
}

local function trim(value)
  if not value then
    return nil
  end
  local result = value:match("^%s*(.-)%s*$")
  return (result and #result > 0) and result or nil
end

local function resolve_tmux_from_path()
  local handle = io.popen("command -v tmux 2>/dev/null")
  if not handle then
    return nil
  end

  local result = trim(handle:read("*a"))
  handle:close()
  return result
end

local function resolve_tmux_from_homebrew()
  for _, path in ipairs(HOMEBREW_TMUX_PATHS) do
    local f = io.open(path, "r")
    if f then
      f:close()
      return path
    end
  end
  return nil
end

-- Resolve tmux binary path once at config load.
-- run_child_process yields across C-call boundary at require time, so use
-- io.popen (synchronous) first, then wezterm.glob for Homebrew fallback.
M.bin = resolve_tmux_from_path() or resolve_tmux_from_homebrew()

local function foreground_is_tmux(pane)
  local proc = pane:get_foreground_process_name()
  return proc ~= nil and proc:match("tmux") ~= nil
end

function M.detect(pane)
  if pane:get_domain_name() == TMUX_DOMAIN_NAME then
    return true
  end
  return foreground_is_tmux(pane)
end

-- Returns true only for tmux CC domain panes, not local panes running tmux.
function M.is_cc(pane)
  return pane:get_domain_name() == TMUX_DOMAIN_NAME
end

return M
