local wezterm = require("wezterm")
local act = wezterm.action
local core = require("tmux.core")
local theme = require("theme")
local claude = require("claude")

local wezterm_cli = wezterm.executable_dir .. "/wezterm"

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
        title = name ~= "" and name or cmd,
        active = active == "1",
        style = (cmd and cmd:match("claude")) and claude.style_for_state("idle") or nil,
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

-- Render a single window as a powerline pill (active) or plain text (inactive),
-- matching theme.lua's tab bar style.  win = { index, title, active, style? }
local function append_window_pill(elements, win, bar_bg)
  local style = win.style
  local idx_label = string.format("%d: %s ", win.index, win.title)

  if win.active then
    local bg = (style and style.bg) or theme.surface
    local fg = (style and style.fg) or theme.text

    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = theme.SOLID_RIGHT })
    table.insert(elements, { Background = { Color = bg } })
    table.insert(elements, { Foreground = { Color = fg } })
    table.insert(elements, { Text = " " })
    if style and style.icon and style.icon ~= "" then
      table.insert(elements, { Text = style.icon .. " " })
    end
    if style and style.bold then
      table.insert(elements, { Attribute = { Intensity = "Bold" } })
    end
    table.insert(elements, { Text = idx_label })
    if style and style.bold then
      table.insert(elements, { Attribute = { Intensity = "Normal" } })
    end
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = bg } })
    table.insert(elements, { Text = theme.SOLID_LEFT })
  else
    table.insert(elements, { Background = { Color = bar_bg } })
    table.insert(elements, { Foreground = { Color = theme.subtext } })
    table.insert(elements, { Text = " " })
    if style and style.icon and style.icon ~= "" then
      local icon_fg = theme.lerp_color(style.bg or theme.subtext, theme.subtext, 0.35)
      table.insert(elements, { Foreground = { Color = icon_fg } })
      table.insert(elements, { Text = style.icon .. " " })
      table.insert(elements, { Foreground = { Color = theme.subtext } })
    end
    table.insert(elements, { Text = idx_label })
  end
end

-- Extract real tab data from a mux window.
-- Returns normalized windows (same shape as gather_all output) or empty table.
local function mux_window_tabs(mux_win)
  local windows = {}
  local active_tab = mux_win:active_tab()
  local active_tab_id = active_tab and active_tab:tab_id()
  for ti, tab in ipairs(mux_win:tabs()) do
    local pane = tab:active_pane()
    if not pane then goto continue end
    local vars = pane:get_user_vars()
    if vars.tmux_cc_control ~= "true" then
      -- Resolve title: explicit > CWD basename > pane title (mirrors theme.lua)
      local title = tab:get_title()
      if not title or #title == 0 then
        local cwd = pane:get_current_working_dir()
        if cwd then
          local path = cwd.file_path or ""
          local basename = path:match("([^/]+)/?$")
          if basename and #basename > 0 then title = basename end
        end
      end
      if not title or #title == 0 then
        title = pane:get_title()
      end
      table.insert(windows, {
        index = ti,
        title = title or "?",
        active = tab:tab_id() == active_tab_id,
        style = claude.style_for_state(vars.claude_state),
      })
    end
    ::continue::
  end
  return windows
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

local function session_choices(sessions, windows_by_session, current_workspace)
  local choices = {}
  table.insert(choices, { id = ":new", label = new_session_label })
  for _, s in ipairs(sessions) do
    table.insert(choices, {
      id = s.name,
      label = format_session_label(s, windows_by_session[s.name]),
    })
    -- Inline switch shortcut for CC-attached sessions
    if s.cc then
      local is_current = current_workspace == s.name
      local switch_id = is_current and ":default" or ("switch:" .. s.name)
      local switch_label = is_current and "switch to default" or ("switch to " .. s.name)
      table.insert(choices, {
        id = switch_id,
        label = wezterm.format({
          { Background = { Color = theme.base } },
          { Foreground = { Color = theme.overlay } },
          { Text = "   \u{eb6b} " .. switch_label },
        }),
      })
    end
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
    -- Inline attach shortcut for unattached sessions
    if not s.cc and not s.other then
      table.insert(choices, {
        id = "attach:" .. s.name,
        label = wezterm.format({
          { Background = { Color = theme.base } },
          { Foreground = { Color = theme.overlay } },
          { Text = "   \u{eb6b} attach " .. s.name },
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

-- Kill stale tmux-domain panes in a workspace. Enumerates via mux API
-- (synchronous, no socket) and fires kill commands via background_child_process
-- (non-blocking, no deadlock). Returns true if stale panes were found.
local function kill_workspace_panes(workspace_name)
  local pane_ids = {}
  local ok, all_windows = pcall(wezterm.mux.all_windows)
  if not ok or not all_windows then return false end
  for _, mux_win in ipairs(all_windows) do
    if mux_win:get_workspace() == workspace_name then
      for _, tab in ipairs(mux_win:tabs()) do
        for _, pane in ipairs(tab:panes()) do
          if core.is_cc(pane) then
            table.insert(pane_ids, tostring(pane:pane_id()))
          end
        end
      end
    end
  end
  if #pane_ids == 0 then return false end
  local parts = {}
  for _, id in ipairs(pane_ids) do
    table.insert(parts, string.format("%q cli kill-pane --pane-id=%s", wezterm_cli, id))
  end
  wezterm.background_child_process({ "sh", "-c", table.concat(parts, "; ") })
  return true
end

local function cc_attach_spawn(session_name)
  return {
    domain = { DomainName = "local" },
    args = {
      "sh", "-c",
      'printf \'\\033]1337;SetUserVar=%s=%s\\007\' tmux_cc_control dHJ1ZQ== && exec "$0" "$@"',
      core.bin, "-CC", "attach", "-t", session_name,
    },
  }
end

local function do_attach(win, p, session_name)
  if not kill_workspace_panes(session_name) then
    -- No stale workspace: SwitchToWorkspace with spawn works immediately.
    win:perform_action(
      act.SwitchToWorkspace({
        name = session_name,
        spawn = cc_attach_spawn(session_name),
      }),
      p
    )
    return
  end
  -- Stale workspace existed: wait for pane kills, then spawn fresh CC pane.
  wezterm.time.call_after(0.5, function()
    local spawn_args = cc_attach_spawn(session_name)
    spawn_args.workspace = session_name
    local sok, err = pcall(function()
      wezterm.mux.spawn_window(spawn_args)
      wezterm.mux.set_active_workspace(session_name)
    end)
    if not sok then
      wezterm.log_warn("do_attach spawn failed: " .. tostring(err))
    end
  end)
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
          wezterm.time.call_after(1, function() kill_workspace_panes(session_name) end)
        elseif action_id == "attach" then
          do_attach(win, p, session_name)
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

  -- For CC-attached sessions, use real workspace tab data (titles, claude state)
  local ok, all_mux = pcall(function() return wezterm.mux.all_windows() end)
  if ok and all_mux then
    local mux_by_ws = {}
    for _, mux_win in ipairs(all_mux) do
      mux_by_ws[mux_win:get_workspace()] = mux_win
    end
    for _, s in ipairs(sessions) do
      if s.cc and mux_by_ws[s.name] then
        local ws = mux_window_tabs(mux_by_ws[s.name])
        if #ws > 0 then
          windows_by_session[s.name] = ws
        end
      end
    end
  end

  local current_workspace = window:active_workspace()
  local choices
  if #sessions == 0 then
    choices = { { id = ":new", label = new_session_label } }
  else
    choices = session_choices(sessions, windows_by_session, current_workspace)
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
        -- Switch to default workspace
        if id == ":default" then
          win:perform_action(act.SwitchToWorkspace({ name = "default" }), p)
          return
        end
        -- Inline switch: switch to CC session workspace
        local switch_target = id:match("^switch:(.+)$")
        if switch_target then
          win:perform_action(act.SwitchToWorkspace({ name = switch_target }), p)
          return
        end
        -- Inline detach: detach other clients from session, then re-open manager
        local detach_target = id:match("^detach:(.+)$")
        if detach_target then
          wezterm.run_child_process({ core.bin, "detach-client", "-s", detach_target })
          wezterm.time.call_after(1, function() kill_workspace_panes(detach_target) end)
          show_sessions(win, p)
          return
        end
        -- Inline attach: directly attach via tmux -CC
        local attach_target = id:match("^attach:(.+)$")
        if attach_target then
          do_attach(win, p, attach_target)
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
