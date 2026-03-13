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
- **`resize.lua`** — `Alt+R` cycles active pane through size presets (25/33/50/67/75%); detects split axis automatically
- **`help.lua`** — F1 InputSelector cheat sheet listing all keybindings in two-column layout
- **`hooked/claude-state.sh`** — Claude Code hook script (Linux); emits OSC 1337 SetUserVar to ancestor PTY for tab state tracking; handles tmux passthrough
- **`hooked/claude-state.zsh`** — Claude Code hook script (macOS); same as above using `ps` instead of `/proc`

## Keybindings

Nine custom keys across five modules:

| Key | Action | Module |
|-----|--------|--------|
| `Ctrl+Shift+D` | Split horizontal | `keys.lua` |
| `Ctrl+Shift+E` | Split vertical | `keys.lua` |
| `Ctrl+Shift+K` | Kill pane (no confirm) | `keys.lua` |
| `Shift+Enter` | CSI u sequence (tmux-safe) | `keys.lua` |
| `F2` | Rename tab / tmux window | `keys.lua` |
| `Alt+R` | Cycle pane resize presets | `resize.lua` |
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
- `tmux.detect(pane)` in `tmux.lua` checks domain name and foreground process (matches both CC and local tmux panes)
- `tmux.is_cc(pane)` returns true only for tmux CC domain panes (domain contains "mux"), not local panes where tmux is the foreground process; use this when running tmux commands via `run_child_process`
- `tmux.resolve_session()` finds the CC-attached tmux session name via `list-clients`; returns nil if no CC client
- `tmux.resolve_window()` returns the `@window_id` of the session's active window (synced by CC); returns nil on failure for graceful degradation
- `tmux.resolve_pane()` returns the `%pane_id` of the session's active pane; use for pane-targeting commands like `kill-pane`
- `tmux.bin` resolves the tmux binary path once at config load (PATH then Homebrew fallback)
- `enabled` in `health.lua` is module-level mutable state toggled via keybinding callback
- The `update-status` event drives both left status (tmux/shell indicator) and right status (health reminder)
- All color constants live in `theme.lua` as the single source of truth; modules require theme and use `theme.green`, `theme.subtext`, etc.
- `theme.register_pane_style(fn)` lets modules inject custom tab styling; `claude.lua` uses this for state-based tab indicators
- `hooked/claude-state.sh` (Linux) walks `/proc` to find ancestor PTY since Claude Code redirects hook stdout; `hooked/claude-state.zsh` (macOS) uses `ps` instead
- Hook events: `SessionStart` (startup|resume) → idle, `UserPromptSubmit` → running, `PreToolUse` → running (except `AskUserQuestion`/`ExitPlanMode` → asking), `PostToolUse` (`AskUserQuestion`/`ExitPlanMode`) → running, `PermissionRequest` → asking, `Notification` (permission_prompt, elicitation_dialog) → asking (backup), `SubagentStart` → running, `Stop` → idle, `SessionEnd` → clear (no argument); configured in `~/.claude/settings.json`
- Avoided hooks: `SubagentStop` races with `Stop` — it fires twice per subagent (converted inner Stop + actual SubagentStop) and the second completes after `Stop`, overwriting idle with running. `Notification idle_prompt` races with `Stop` via mutual `has_bg_shell` detection. Both are redundant (`PreToolUse`/`UserPromptSubmit` already cover running, `Stop` covers idle).
