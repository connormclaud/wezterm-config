# WezTerm Config

## Claude Operator Console

![Screenshot](assets/screenshot.png)

Modular [WezTerm](https://wezfurlong.org/wezterm/) configuration with Catppuccin Mocha theme, tmux integration, and quality-of-life extras.

## Features

- **Catppuccin Mocha** color scheme with polished translucent background, tuned typography, powerline tab bar, and active-pane focus contrast
- **Tmux integration** — auto-detects tmux panes, session picker (`Ctrl+Shift+A`), context-aware tab rename
- **20-20-20 health reminders** — status bar warning every 20 minutes to look away for 20 seconds
- **Agent tab tracking** — Claude Code and Codex surface Nerd Font icons and colored powerline tabs by state: 󰚩 running (blue), asking (peach, Claude-only), 󰄬 idle (green)
- **F1 cheat sheet** — overlay listing all keybindings

## Structure

| File | Purpose |
|------|---------|
| `wezterm.lua` | Entry point — loads modules, merges keybindings, sets up status bar |
| `theme.lua` | Catppuccin Mocha palette + tab title rendering with pane style registry |
| `claude.lua` | Registers Claude Code tab state styles (running/asking/idle) with theme |
| `keys.lua` | Pane splits, kill pane, Shift+Enter passthrough, F2 rename |
| `tmux.lua` | Tmux detection, binary resolution, session picker, left status |
| `health.lua` | 20-20-20 reminder with toggle |
| `help.lua` | F1 keybinding cheat sheet |
| `hooked/claude-state.sh` | Shared Claude Code / Codex hook — emits WezTerm user vars for tab state (Linux) |
| `hooked/claude-state.zsh` | Shared Claude Code / Codex hook — same as above (macOS) |

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+Shift+D` | Split horizontal |
| `Ctrl+Shift+E` | Split vertical |
| `Ctrl+Shift+K` | Kill pane (no confirm) |
| `Ctrl+Shift+O` | Pane select (jump) |
| `Shift+Enter` | CSI u sequence (tmux-safe) |
| `F2` | Rename tab / tmux window |
| `Ctrl+Shift+A` | Tmux session picker |
| `Ctrl+Shift+H` | Toggle health reminder |
| `F1` | Help overlay |

## Install

```bash
git clone https://github.com/connormclaud/wezterm.git ~/.config/wezterm
```

WezTerm hot-reloads on save. To validate syntax:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts
```

## Claude Code And Codex Tab Tracking

Active tabs show state as a colored powerline pill; inactive tabs show compact colored badges (state and/or unseen output):

| State | Icon | Color | Active | Inactive |
|-------|------|-------|--------|----------|
| Running | 󰚩 | Blue | Pill bg | Colored badge |
| Asking | | Peach | Pill bg | Colored badge |
| Idle | 󰄬 | Green | Pill bg | Colored badge |

Requires [Symbols Nerd Font Mono](https://www.nerdfonts.com/) installed as a font fallback.

Claude Code supports all three states. Codex currently supports `running` and `idle` only because its hook surface does not yet expose a reliable asking/input-needed event.

State clears automatically when Claude Code exits (`SessionEnd` hook).

This uses [Claude Code hooks](https://code.claude.com/docs/en/hooks). Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|resume",
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh idle", "async": true }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh running", "async": true }]
    }],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion|ExitPlanMode",
        "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh asking", "async": true }]
      },
      {
        "matcher": "^(?!AskUserQuestion$|ExitPlanMode$)",
        "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh running", "async": true }]
      }
    ],
    "PostToolUse": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh running", "async": true }]
    }],
    "PermissionRequest": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh asking", "async": true }]
    }],
    "SubagentStart": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh running", "async": true }]
    }],
    "Elicitation": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh asking", "async": true }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh idle", "async": true }]
    }],
    "StopFailure": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh idle", "async": true }]
    }],
    "SessionEnd": [{
      "hooks": [{ "type": "command", "command": "$HOME/.config/wezterm/hooked/claude-state.sh", "async": true }]
    }]
  }
}
```

On macOS, use `claude-state.zsh` instead — it resolves the TTY via `ps` rather than `/proc`.

### Codex Setup

Codex hooks are currently experimental and configured globally rather than through this repo.

In `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

In `~/.codex/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/wezterm/hooked/claude-state.sh idle"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/wezterm/hooked/claude-state.sh running"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/wezterm/hooked/claude-state.sh running"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/wezterm/hooked/claude-state.sh running"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/wezterm/hooked/claude-state.sh idle"
          }
        ]
      }
    ]
  }
}
```

Codex does not currently expose a `SessionEnd` hook, so clear the state from your shell wrapper after the `codex` process exits:

```bash
codex() {
  command codex "$@"
  local status=$?
  "$HOME/.config/wezterm/hooked/claude-state.sh"
  return $status
}
```

## See Also

- [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config) — feature-rich modular config with background selector, GPU adapter picker, and CI linting
- [dragonlobster/wezterm-config](https://github.com/dragonlobster/wezterm-config) — clean single-file config with a great YouTube walkthrough
- [awesome-wezterm](https://github.com/michaelbrusegard/awesome-wezterm) — curated list of WezTerm plugins and resources
- [catppuccin/wezterm](https://github.com/catppuccin/wezterm) — official Catppuccin theme for WezTerm

## License

[MIT](LICENSE)
