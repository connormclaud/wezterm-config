local wezterm = require("wezterm")
local act = wezterm.action
local core = require("tmux.core")
local theme = require("theme")

local M = {}

-- Returns { [session_name] = { cc = bool, other = bool } }
local function gather_clients()
  if not core.bin then return {} end
  local ok, out = wezterm.run_child_process({
    core.bin, "list-clients", "-F",
    "#{client_control_mode}\t#{client_session}",
  })
  if not ok then return {} end
  local by_session = {}
  for line in out:gmatch("[^\n]+") do
    local mode, sess = line:match("^(%d+)\t(.+)$")
    if sess then
      by_session[sess] = by_session[sess] or { cc = false, other = false }
      if mode == "1" then
        by_session[sess].cc = true
      else
        by_session[sess].other = true
      end
    end
  end
  return by_session
end

-- Gather sessions and windows in a single tmux call, plus clients for attach state.
-- Returns sessions (array), windows_by_session (table).
local function gather_all()
  if not core.bin then return nil, {} end
  local ok, out = wezterm.run_child_process({
    core.bin, "list-windows", "-a", "-F",
    "#{session_name}\t#{window_index}\t#{window_name}\t#{window_active}\t#{pane_current_command}",
  })
  if not ok then return {}, {} end

  local clients = gather_clients()
  local windows_by_session = {}
  local session_order = {}
  local seen = {}

  for line in out:gmatch("[^\n]+") do
    local sess, idx, name, active, cmd = line:match("^(.-)\t(%d+)\t(.-)\t(%d+)\t(.*)$")
    if sess then
      if not seen[sess] then
        seen[sess] = true
        table.insert(session_order, sess)
      end
      windows_by_session[sess] = windows_by_session[sess] or {}
      table.insert(windows_by_session[sess], {
        index = tonumber(idx),
        name = name,
        active = active == "1",
        command = cmd ~= "" and cmd or name,
      })
    end
  end

  local sessions = {}
  for _, name in ipairs(session_order) do
    local cl = clients[name] or { cc = false, other = false }
    table.insert(sessions, {
      name = name,
      windows = #windows_by_session[name],
      cc = cl.cc,
      other = cl.other,
    })
  end

  return sessions, windows_by_session
end

-- Shared icon prefix for window pills (claude gets idle icon, others get space).
local function window_prefix(is_claude)
  if is_claude then
    return " " .. theme.ICON_IDLE .. " "
  end
  return " "
end

-- Render a single window as a powerline pill (active) or plain text (inactive),
-- matching theme.lua's tab bar style.
local function append_window_pill(elements, win, bar_bg)
  local cmd = win.command
  local is_claude = cmd:match("claude")
  local idx_label = string.format("%d: %s ", win.index, cmd)
  local prefix = window_prefix(is_claude)

  if win.active then
    local bg = is_claude and theme.green or theme.surface
    local fg = is_claude and theme.base or theme.text

    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = theme.SOLID_RIGHT })
    table.insert(elements, { Background = { Color = bg } })
    table.insert(elements, { Foreground = { Color = fg } })
    table.insert(elements, { Text = prefix })
    table.insert(elements, { Attribute = { Intensity = "Bold" } })
    table.insert(elements, { Text = idx_label })
    table.insert(elements, { Attribute = { Intensity = "Normal" } })
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = theme.SOLID_LEFT })
  else
    local text_fg = is_claude and theme.green or theme.subtext
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = text_fg } })
    table.insert(elements, { Text = prefix })
    table.insert(elements, { Text = idx_label })
  end
end

local function format_session_label(session, windows)
  local bar_bg = theme.base
  local elements = {}

  -- Session name: green if CC-attached (ours), peach if other-attached, white if detached
  local name_color = session.cc and theme.green or session.other and theme.peach or theme.text
  table.insert(elements, { Background = { Color = bar_bg } })
  table.insert(elements, { Foreground = { Color = name_color } })
  table.insert(elements, { Attribute = { Intensity = "Bold" } })
  table.insert(elements, { Text = " " .. session.name })
  table.insert(elements, { Attribute = { Intensity = "Normal" } })

  local tag = ""
  if session.cc then
    tag = " (CC)"
  elseif session.other then
    tag = " (attached)"
  end
  if #tag > 0 then
    table.insert(elements, { Foreground = { Color = theme.overlay } })
    table.insert(elements, { Text = tag })
  end

  -- Separator between name and mini tab bar
  local name_len = 1 + #session.name + #tag
  local pad = math.max(2, 22 - name_len)
  table.insert(elements, { Text = string.rep(" ", pad) })

  -- Render windows as mini tab bar
  if windows and #windows > 0 then
    for _, win in ipairs(windows) do
      append_window_pill(elements, win, bar_bg)
    end
  end

  -- Ensure trailing background matches bar
  table.insert(elements, { Background = { Color = bar_bg } })
  table.insert(elements, { Text = " " })

  return wezterm.format(elements)
end

local new_session_label = wezterm.format({
  { Background = { Color = theme.base } },
  { Foreground = { Color = theme.blue } },
  { Text = " + New session " },
})

local function session_choices(sessions, windows_by_session)
  local choices = {}
  table.insert(choices, { id = ":new", label = new_session_label })
  for _, s in ipairs(sessions) do
    table.insert(choices, {
      id = s.name,
      label = format_session_label(s, windows_by_session[s.name]),
    })
    -- Inline detach shortcut for sessions attached by other clients
    if s.other then
      table.insert(choices, {
        id = "detach:" .. s.name,
        label = wezterm.format({
          { Background = { Color = theme.base } },
          { Foreground = { Color = theme.overlay } },
          { Text = "   \u{23cf} detach " .. s.name },
        }),
      })
    end
  end
  return choices
end

local function action_choices(session_name, cc)
  local choices = {}
  if cc then
    table.insert(choices, { id = "switch", label = "Switch to workspace" })
    table.insert(choices, { id = "detach", label = "Detach (CC)" })
  else
    table.insert(choices, { id = "attach", label = "Attach (tmux -CC)" })
  end
  table.insert(choices, { id = "rename",  label = "Rename session" })
  table.insert(choices, { id = "kill",    label = "Kill session" })
  table.insert(choices, { id = "new-win", label = "New window in " .. session_name })
  return choices
end

local function show_actions(window, pane, session_name, cc)
  window:perform_action(
    act.InputSelector({
      title = session_name .. ": actions",
      choices = action_choices(session_name, cc),
      action = wezterm.action_callback(function(win, p, action_id)
        if not action_id then return end

        if action_id == "switch" then
          win:perform_action(
            act.SwitchToWorkspace({ name = session_name }),
            p
          )
        elseif action_id == "detach" then
          wezterm.run_child_process({ core.bin, "detach-client", "-s", session_name })
        elseif action_id == "attach" then
          win:perform_action(
            act.SwitchToWorkspace({
              name = session_name,
              spawn = {
                domain = { DomainName = "local" },
                args = {
                  "sh", "-c",
                  'printf \'\\033]1337;SetUserVar=%s=%s\\007\' tmux_cc_control dHJ1ZQ== && exec "$0" "$@"',
                  core.bin, "-CC", "attach", "-t", session_name,
                },
              },
            }),
            p
          )
        elseif action_id == "rename" then
          win:perform_action(
            act.PromptInputLine({
              description = "Rename session: " .. session_name,
              initial_value = session_name,
              action = wezterm.action_callback(function(_w, _p, line)
                if line and #line > 0 then
                  wezterm.run_child_process({
                    core.bin, "rename-session", "-t", session_name, line,
                  })
                end
              end),
            }),
            p
          )
        elseif action_id == "kill" then
          wezterm.run_child_process({ core.bin, "kill-session", "-t", session_name })
        elseif action_id == "new-win" then
          wezterm.run_child_process({ core.bin, "new-window", "-t", session_name })
        end
      end),
    }),
    pane
  )
end

local function show_sessions(window, pane)
  local sessions, windows_by_session = gather_all()
  if not sessions then
    window:perform_action(
      act.InputSelector({
        title = "tmux sessions",
        choices = { { id = "", label = "tmux not found" } },
        action = wezterm.action_callback(function() end),
      }),
      pane
    )
    return
  end

  local choices
  if #sessions == 0 then
    choices = { { id = ":new", label = new_session_label } }
  else
    choices = session_choices(sessions, windows_by_session)
  end

  -- Build lookup for CC state so the callback can pass it to show_actions
  local cc_by_name = {}
  for _, s in ipairs(sessions) do
    cc_by_name[s.name] = s.cc
  end

  window:perform_action(
    act.InputSelector({
      title = "tmux sessions",
      description = "Enter = actions  / = filter  Esc = close",
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        if not id then return end
        if id == ":new" then
          win:perform_action(
            act.PromptInputLine({
              description = "New tmux session name",
              action = wezterm.action_callback(function(w2, p2, line)
                if line and #line > 0 then
                  wezterm.run_child_process({ core.bin, "new-session", "-d", "-s", line })
                  show_actions(w2, p2, line, false)
                end
              end),
            }),
            p
          )
          return
        end
        -- Inline detach: detach other clients from session, then re-open manager
        local detach_target = id:match("^detach:(.+)$")
        if detach_target then
          wezterm.run_child_process({ core.bin, "detach-client", "-s", detach_target })
          show_sessions(win, p)
          return
        end
        show_actions(win, p, id, cc_by_name[id] or false)
      end),
    }),
    pane
  )
end

function M.keys()
  return {
    {
      key = "a",
      mods = "CTRL|SHIFT",
      action = wezterm.action_callback(function(window, pane)
        show_sessions(window, pane)
      end),
    },
  }
end

return M
