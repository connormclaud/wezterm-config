# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a WezTerm terminal emulator configuration, split into modular Lua files.

## Architecture

The config uses `wezterm.config_builder()` with a modular structure:

- **`wezterm.lua`** — entry point; loads modules, merges keybindings from each module's `keys()` export, sets up the `update-status` event (left status from tmux, right status from health)
- **`keys.lua`** — pane splits, pane kill, Shift+Enter CSI u passthrough, F2 context-aware tab/tmux rename (pre-fills current name)
- **`tmux.lua`** — `tmux.detect(pane)` checks domain name and foreground process; `tmux.bin` resolves tmux path at config load (PATH first, then Homebrew fallback); left status indicator; `Ctrl+Shift+A` session picker that attaches via `tmux -CC`
- **`health.lua`** — 20-20-20 rule: right-status warning every 20 minutes for 25 seconds; `Ctrl+Shift+H` toggle; `enabled` is module-level mutable state
- **`help.lua`** — F1 InputSelector cheat sheet listing all keybindings in two-column layout

## Keybindings

Eight custom keys across four modules:

| Key | Action | Module |
|-----|--------|--------|
| `Ctrl+Shift+D` | Split horizontal | `keys.lua` |
| `Ctrl+Shift+E` | Split vertical | `keys.lua` |
| `Ctrl+Shift+K` | Kill pane (no confirm) | `keys.lua` |
| `Shift+Enter` | CSI u sequence (tmux-safe) | `keys.lua` |
| `F2` | Rename tab / tmux window | `keys.lua` |
| `Ctrl+Shift+A` | Tmux session picker | `tmux.lua` |
| `Ctrl+Shift+H` | Health reminder toggle | `health.lua` |
| `F1` | Help overlay | `help.lua` |

## Testing Changes

WezTerm hot-reloads `wezterm.lua` on save. To validate config syntax without reloading:

```
wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts
```

Errors appear in WezTerm's debug overlay: `Ctrl+Shift+L`.

## Key Conventions

- Config is pure Lua using the WezTerm API (`wezterm` module)
- Each module exports a `keys()` function; `wezterm.lua` merges them all into `config.keys`
- `tmux.detect(pane)` in `tmux.lua` checks domain name and foreground process
- `tmux.bin` resolves the tmux binary path once at config load (PATH then Homebrew fallback)
- `enabled` in `health.lua` is module-level mutable state toggled via keybinding callback
- The `update-status` event drives both left status (tmux/shell indicator) and right status (health reminder)
- Color constants (`col_green`, `col_subtext`, `col_yellow`) use catppuccin mocha palette values
