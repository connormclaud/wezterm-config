local wezterm = require("wezterm")
local config = wezterm.config_builder()

local theme  = require("theme")
local claude = require("claude")
local tmux   = require("tmux")
local health = require("health")
local help   = require("help")
local keys   = require("keys")
local resize = require("resize")
require("border")

-- Typography: slightly larger + tighter rhythm for readability/polish
config.font = wezterm.font_with_fallback({
  { family = "Iosevka", weight = "Medium" },
  "Symbols Nerd Font Mono",
})
config.font_size = 14.5
config.line_height = 1.15

-- Color scheme
config.color_scheme = "catppuccin-mocha"

-- Window: borderless, padded, translucent
-- NONE on Linux/Wayland avoids CSD miscalculating window area when maximized (#6318, #6834)
-- RESIZE on macOS keeps native resize handles
config.window_decorations = wezterm.target_triple:find("linux") and "NONE" or "RESIZE"
config.window_padding = { left = 16, right = 16, top = 12, bottom = 12 }
config.window_background_opacity = wezterm.target_triple:find("darwin") and 1.0 or 0.965
config.window_frame = theme.make_window_frame(theme.toxic)

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
config.colors.split = theme.overlay

-- Pane focus: dim inactive panes to improve active-pane contrast in splits
config.inactive_pane_hsb = {
  saturation = 0.88,
  brightness = 0.75,
}

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

-- Rendering
config.enable_wayland = true

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
  pcall(health.update_right_status, window, pane)
  pcall(tmux.sync_cc_client_size, window, pane)
end)

-- Sync tmux CC client dimensions on window resize so new tmux windows
-- get the correct size (workaround for WezTerm not sending refresh-client -C)
wezterm.on("window-resized", function(window, pane)
  -- Clear cached size so next update-status re-syncs
  local key = "cc_size_" .. tostring(window:window_id())
  if wezterm.GLOBAL.cc_synced then
    wezterm.GLOBAL.cc_synced[key] = nil
  end
end)

return config
