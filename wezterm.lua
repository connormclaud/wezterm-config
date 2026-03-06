local wezterm = require("wezterm")
local config = wezterm.config_builder()

local tmux   = require("tmux")
local health = require("health")
local help   = require("help")
local keys   = require("keys")

-- Font: Iosevka at a comfortable size for 4K HiDPI
config.font = wezterm.font("Iosevka", { weight = "Regular" })
config.font_size = 13.0
config.line_height = 1.2

-- Color scheme
config.color_scheme = "catppuccin-mocha"

-- Window: borderless, padded, translucent
config.window_decorations = "RESIZE"
config.window_padding = { left = 16, right = 16, top = 12, bottom = 12 }
config.window_background_opacity = 0.93
config.macos_window_background_blur = 20

-- Cursor
config.default_cursor_style = "SteadyBar"
config.cursor_thickness = 2

-- Tab bar: minimal bottom bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = false

-- Scrollback
config.scrollback_lines = 100000

-- Visual bell
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_function = "EaseIn",
  fade_in_duration_ms = 80,
  fade_out_function = "EaseOut",
  fade_out_duration_ms = 80,
  target = "CursorColor",
}

-- Initial window size: ~75% of screen, centered
-- Uses window-config-reloaded instead of gui-startup because
-- wezterm.gui.screens() is unavailable during gui-startup (#6936)
wezterm.on("window-config-reloaded", function(window, pane)
  local id = tostring(window:window_id())
  local seen = wezterm.GLOBAL.seen_windows or {}
  if seen[id] then return end
  seen[id] = true
  wezterm.GLOBAL.seen_windows = seen

  local ok, screens = pcall(wezterm.gui.screens)
  if not ok or not screens.active then return end
  local screen = screens.active
  local w = math.floor(screen.width * 0.75)
  local h = math.floor(screen.height * 0.75)
  local x = math.floor((screen.width - w) / 2)
  local y = math.floor((screen.height - h) / 2)
  window:set_position(x, y)
  window:set_inner_size(w, h)
end)

-- Rendering
config.enable_wayland = true
config.front_end = "WebGpu"
config.webgpu_power_preference = "LowPower"

-- Misc
config.enable_kitty_keyboard = true
config.check_for_updates = false
config.adjust_window_size_when_changing_font_size = false
config.warn_about_missing_glyphs = false

-- Compose keybindings from all modules
config.keys = {}
for _, mod in ipairs({ tmux, health, help, keys }) do
  for _, k in ipairs(mod.keys()) do
    table.insert(config.keys, k)
  end
end

-- Tab activity colors (catppuccin mocha)
local col_text    = "#cdd6f4"
local col_green   = "#a6e3a1"
local col_yellow  = "#f9e2af"
local col_overlay = "#6c7086"
local col_surface = "#45475a"

-- Tab title: index + cwd folder, respects F2 manual rename
-- Colors: active = bright on surface, claude-idle = bold green ✓,
--         unseen output = yellow •, quiet = dimmed
wezterm.on("format-tab-title", function(tab)
  local index = tab.tab_index + 1
  -- F2 rename takes priority
  local title = tab.tab_title
  if not title or #title == 0 then
    local cwd = tab.active_pane.current_working_dir
    if cwd then
      local path = cwd.file_path or ""
      title = path:match("([^/]+)/?$") or ""
    end
    if not title or #title == 0 then
      title = tab.active_pane.title
    end
  end

  if tab.is_active then
    return {
      { Background = { Color = col_surface } },
      { Foreground = { Color = col_text } },
      { Text = string.format(" %d: %s ", index, title) },
    }
  elseif tab.active_pane.user_vars.claude_state == "idle" then
    return {
      { Foreground = { Color = col_green } },
      { Attribute = { Intensity = "Bold" } },
      { Text = string.format(" %d: %s ✓ ", index, title) },
    }
  elseif tab.active_pane.has_unseen_output then
    return {
      { Foreground = { Color = col_yellow } },
      { Text = string.format(" %d: %s • ", index, title) },
    }
  else
    return {
      { Foreground = { Color = col_overlay } },
      { Text = string.format(" %d: %s ", index, title) },
    }
  end
end)

-- Status bar: left from tmux, right from health
wezterm.on("update-status", function(window, pane)
  tmux.update_left_status(window, pane)
  health.update_right_status(window)
end)

return config
