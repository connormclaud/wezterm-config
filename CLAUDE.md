# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a WezTerm terminal emulator configuration, split into modular Lua files.

## Architecture

The config uses `wezterm.config_builder()` with a modular structure:

- **`wezterm.lua`** — entry point; loads modules, merges keybindings from each module's `keys()` export, sets up the `update-status` event (left status from tmux, right status from health)
- **`theme.lua`** — catppuccin mocha palette (single source of truth); powerline glyph and Nerd Font icon constants; owns `format-tab-title` with retro tab bar powerline rendering and `register_pane_style(fn)` for module-injected per-pane styling
- **`claude.lua`** — registers Claude Code tab state styles (running/asking/idle) with theme via `register_pane_style`; returns `{ bg, fg, icon, bold }` tables consumed by theme's powerline renderer; uses static colors (no escalation) for performance
- **`keys.lua`** — declarative keybinding table: pane splits, Shift+Enter CSI u passthrough, plus tmux action factories from `tmux.lua` (kill pane, rename tab, move tab)
- **`tmux.lua`** — `tmux.detect(pane)` checks domain name and foreground process; `tmux.bin` resolves tmux path at config load (PATH first, then Homebrew fallback); action factories (`kill_pane_action`, `rename_tab_action`, `move_tab_action`) encapsulate all tmux-vs-local branching; left status indicator; `Ctrl+Shift+A` session picker that attaches via `tmux -CC`
- **`health.lua`** — 20-20-20 rule: right-status warning every 20 minutes for 25 seconds; `Ctrl+Shift+H` toggle; `enabled` is module-level mutable state
- **`resize.lua`** — `Alt+R` cycles active pane through size presets (25/33/50/67/75%); detects split axis automatically
- **`help.lua`** — F1 InputSelector cheat sheet listing all keybindings in two-column layout
- **`hooked/claude-state.sh`** — Claude Code hook script (Linux); emits OSC 1337 SetUserVar to ancestor PTY for tab state tracking; handles tmux passthrough
- **`hooked/claude-state.zsh`** — Claude Code hook script (macOS); same as above using `ps` instead of `/proc`

## Keybindings

Eleven custom keys across five modules:

| Key | Action | Module |
|-----|--------|--------|
| `Ctrl+Shift+D` | Split horizontal | `keys.lua` |
| `Ctrl+Shift+E` | Split vertical | `keys.lua` |
| `Ctrl+Shift+K` | Kill pane (no confirm) | `keys.lua` → `tmux.kill_pane_action` |
| `Shift+Enter` | CSI u sequence (tmux-safe) | `keys.lua` |
| `F2` | Rename tab / tmux window | `keys.lua` → `tmux.rename_tab_action` |
| `Ctrl+Shift+PageUp` | Move tab left | `keys.lua` → `tmux.move_tab_action` |
| `Ctrl+Shift+PageDown` | Move tab right | `keys.lua` → `tmux.move_tab_action` |
| `Alt+R` | Cycle pane resize presets | `resize.lua` |
| `Ctrl+Shift+A` | Tmux session picker | `tmux.lua` |
| `Ctrl+Shift+H` | Health reminder toggle | `health.lua` |
| `F1` | Help overlay | `help.lua` |

## Testing Changes

WezTerm hot-reloads `wezterm.lua` on save. To validate config syntax without reloading:

```
wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts
```

Errors appear in WezTerm's debug overlay: `Ctrl+Shift+L`. Runtime logs live at `/run/user/$UID/wezterm/wezterm-gui-log-*.txt` (most recent file is the active session). After making changes, check the log for new warnings — but note the debug overlay shows the full session history including transient errors from earlier hot-reloads, so always check timestamps.

## Key Conventions

- Config is pure Lua using the WezTerm API (`wezterm` module)
- Each module exports a `keys()` function; `wezterm.lua` merges them all into `config.keys`
- `tmux.lua` exports action factories (`kill_pane_action`, `rename_tab_action`, `move_tab_action`) that encapsulate all tmux-vs-local branching; `keys.lua` is a purely declarative binding table that calls these factories
- `tmux.detect(pane)` in `tmux.lua` checks domain name and foreground process (matches both CC and local tmux panes)
- `tmux.is_cc(pane)` returns true only for tmux CC domain panes (domain equals `"tmux"`, the hardcoded TmuxDomain name), not local panes where tmux is the foreground process; use this when running tmux commands via `run_child_process`
- `tmux.resolve_session()` finds the CC-attached tmux session name via `list-clients`; returns nil if no CC client
- `tmux.resolve_window()` returns the `@window_id` of the session's active window (synced by CC); returns nil on failure for graceful degradation
- `tmux.resolve_pane()` returns the `%pane_id` of the session's active pane; use for pane-targeting commands like `kill-pane`
- `tmux.bin` resolves the tmux binary path once at config load (PATH then Homebrew fallback)
- `enabled` in `health.lua` is module-level mutable state toggled via keybinding callback
- The `update-status` event drives both left status (tmux/shell indicator) and right status (health reminder)
- All color constants, powerline glyphs (`SOLID_RIGHT`, `SOLID_LEFT`), and Nerd Font icons (`ICON_RUNNING`, `ICON_ASKING`, `ICON_IDLE`) live in `theme.lua` as the single source of truth; modules require theme and use `theme.green`, `theme.subtext`, etc.
- The tab bar uses retro mode (`use_fancy_tab_bar = false`) for full powerline rendering; `wezterm.font_with_fallback` adds Symbols Nerd Font Mono for glyph coverage
- `theme.register_pane_style(fn)` lets modules inject custom tab styling; callbacks return `{ bg, fg, icon, bold }` or nil; active tabs render as colored powerline pills, inactive tabs with state render as colored text
- Health icons use Nerd Font glyphs (eye, bell, bell-slash) to match the flat theme
- `hooked/claude-state.sh` (Linux) walks `/proc` to find ancestor PTY since Claude Code redirects hook stdout; `hooked/claude-state.zsh` (macOS) uses `ps` instead
- Hook events: `SessionStart` (startup|resume) → idle, `UserPromptSubmit` → running, `PreToolUse` → running (except `AskUserQuestion`/`ExitPlanMode` → asking), `PostToolUse` → running (catch-all; clears asking after permission approval or answered question), `PermissionRequest` → asking, `SubagentStart` → running, `Stop` → idle, `SessionEnd` → clear (no argument); configured in `~/.claude/settings.json`
- Avoided hooks: `SubagentStop` races with `Stop` — it fires twice per subagent (converted inner Stop + actual SubagentStop) and the second completes after `Stop`, overwriting idle with running. `Notification` hooks race with `PostToolUse`/`Stop` — async backup signals can arrive late and overwrite state transitions; `PermissionRequest` and `PreToolUse` already cover all asking transitions. Both are redundant (`PreToolUse`/`UserPromptSubmit` already cover running, `Stop` covers idle).
