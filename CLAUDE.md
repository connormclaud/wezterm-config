# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a WezTerm terminal emulator configuration, split into modular Lua files.

## Architecture

The config uses `wezterm.config_builder()` with a modular structure:

- **`wezterm.lua`** — entry point; loads modules, merges keybindings from each module's `keys()` export, sets up the `update-status` event (left status from tmux, right status from health)
- **`theme.lua`** — catppuccin mocha palette (single source of truth); owns `format-tab-title` with `register_pane_style(fn)` for module-injected per-pane styling
- **`claude.lua`** — registers Claude Code tab state styles (running/asking/idle) with theme via `register_pane_style`
- **`keys.lua`** — pane splits, pane kill, Shift+Enter CSI u passthrough, F2 context-aware tab/tmux rename (pre-fills current name)
- **`tmux.lua`** — `tmux.detect(pane)` checks domain name and foreground process; `tmux.bin` resolves tmux path at config load (PATH first, then Homebrew fallback); left status indicator; `Ctrl+Shift+A` session picker that attaches via `tmux -CC`
- **`health.lua`** — 20-20-20 rule: right-status warning every 20 minutes for 25 seconds; `Ctrl+Shift+H` toggle; `enabled` is module-level mutable state
- **`help.lua`** — F1 InputSelector cheat sheet listing all keybindings in two-column layout
- **`hooks/claude-state.sh`** — Claude Code hook script (Linux); emits OSC 1337 SetUserVar to ancestor PTY for tab state tracking; handles tmux passthrough
- **`hooks/claude-state.zsh`** — Claude Code hook script (macOS); same as above using `ps` instead of `/proc`

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
- All color constants live in `theme.lua` as the single source of truth; modules require theme and use `theme.green`, `theme.subtext`, etc.
- `theme.register_pane_style(fn)` lets modules inject custom tab styling; `claude.lua` uses this for state-based tab indicators
- `hooks/claude-state.sh` (Linux) walks `/proc` to find ancestor PTY since Claude Code redirects hook stdout; `hooks/claude-state.zsh` (macOS) uses `ps` instead
- Hook events: `PreToolUse` → running, `Notification` → asking, `Stop` → idle, `SessionEnd` → clear (no argument); configured in `~/.claude/settings.json`
