local wezterm = require("wezterm")
local config = wezterm.config_builder()

local theme  = require("theme")
local claude = require("claude")
local tmux   = require("tmux")
local health = require("health")
local help   = require("help")
local keys   = require("keys")
local resize = require("resize")

-- Font: Iosevka at a comfortable size for 4K HiDPI
config.font = wezterm.font_with_fallback({
  { family = "Iosevka", weight = "Regular" },
  "Symbols Nerd Font Mono",
})
config.font_size = 14.0
config.line_height = 1.2

-- Color scheme
config.color_scheme = "catppuccin-mocha"

-- Window: borderless, padded, translucent
-- NONE on Linux/Wayland avoids CSD miscalculating window area when maximized (#6318, #6834)
-- RESIZE on macOS keeps native resize handles
config.window_decorations = wezterm.target_triple:find("linux") and "NONE" or "RESIZE"
config.window_padding = { left = 16, right = 16, top = 12, bottom = 12 }
config.window_background_opacity = 0.93
config.macos_window_background_blur = 20
config.window_frame = {
  border_left_width    = "1px",
  border_right_width   = "1px",
  border_top_height    = "1px",
  border_bottom_height = "1px",
  border_left_color    = theme.toxic,
  border_right_color   = theme.toxic,
  border_top_color     = theme.toxic,
  border_bottom_color  = theme.toxic,
  active_titlebar_bg   = theme.base,
  inactive_titlebar_bg = theme.base,
}

-- Cursor
config.default_cursor_style = "SteadyBar"
config.cursor_thickness = 2

-- Tab bar: minimal bottom bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 48
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false

-- Tab bar colors (retro mode — format-tab-title handles per-tab rendering)
-- Merge into config.colors to avoid clobbering any color_scheme overrides
config.colors = config.colors or {}
config.colors.tab_bar = { background = theme.base }

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
for _, mod in ipairs({ tmux, health, help, keys, resize }) do
  for _, k in ipairs(mod.keys()) do
    table.insert(config.keys, k)
  end
end

-- Tab title rendering (theme owns format-tab-title, claude registers its pane styles)
theme.setup_tab_title()

-- Status bar: left from tmux, right from health
wezterm.on("update-status", function(window, pane)
  pcall(tmux.update_left_status, window, pane)
  health.update_right_status(window)
end)

return config
