local wezterm = require("wezterm")

local M = {}

-- Resolve tmux binary path once at config load.
-- Tries PATH first (works on Linux), then Homebrew fallback (macOS GUI apps
-- don't inherit shell PATH).
M.bin = (function()
  local ok, _, stdout = pcall(wezterm.run_child_process, { "which", "tmux" })
  if ok then
    local p = stdout:match("^%s*(.-)%s*$")
    if p and #p > 0 then return p end
  end
  for _, p in ipairs({ "/opt/homebrew/bin/tmux", "/usr/local/bin/tmux" }) do
    local f = io.open(p, "r")
    if f then f:close(); return p end
  end
  return nil
end)()

function M.detect(pane)
  local domain = pane:get_domain_name()
  if domain and domain:lower():match("mux") then
    return true
  end
  local proc = pane:get_foreground_process_name()
  if proc and proc:match("tmux") then
    return true
  end
  return false
end

-- catppuccin mocha
local col_green  = "#a6e3a1"
local col_subtext = "#a6adc8"

function M.update_left_status(window, pane)
  if M.detect(pane) then
    window:set_left_status(wezterm.format({
      { Foreground = { Color = col_green } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " [tmux]" },
      "ResetAttributes",
      { Foreground = { Color = col_subtext } },
      { Text = " F1:help" },
    }))
  else
    local proc = pane:get_foreground_process_name() or ""
    local shell = proc:match("([^/]+)$") or "shell"
    window:set_left_status(wezterm.format({
      { Foreground = { Color = col_subtext } },
      { Text = string.format(" [%s]", shell) },
    }))
  end
end

function M.keys()
  local act = wezterm.action
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
