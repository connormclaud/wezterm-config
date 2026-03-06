# WezTerm Config

Modular [WezTerm](https://wezfurlong.org/wezterm/) configuration with Catppuccin Mocha theme, tmux integration, and quality-of-life extras.

## Features

- **Catppuccin Mocha** color scheme with translucent, borderless window
- **Tmux integration** — auto-detects tmux panes, session picker (`Ctrl+Shift+A`), context-aware tab rename
- **20-20-20 health reminders** — status bar warning every 20 minutes to look away for 20 seconds
- **Claude Code tab tracking** — tabs show a green checkmark when Claude Code finishes (requires shell integration)
- **F1 cheat sheet** — overlay listing all keybindings

## Structure

| File | Purpose |
|------|---------|
| `wezterm.lua` | Entry point — loads modules, merges keybindings, sets up status bar |
| `keys.lua` | Pane splits, kill pane, Shift+Enter passthrough, F2 rename |
| `tmux.lua` | Tmux detection, binary resolution, session picker, left status |
| `health.lua` | 20-20-20 reminder with toggle |
| `help.lua` | F1 keybinding cheat sheet |
| `shell-integration.zsh` | Claude Code state tracking via WezTerm user vars |

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

Optionally, source the shell integration in `~/.zshrc` for Claude Code tab indicators:

```bash
source ~/.config/wezterm/shell-integration.zsh
```

WezTerm hot-reloads on save. To validate syntax:

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts
```

## See Also

- [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config) — feature-rich modular config with background selector, GPU adapter picker, and CI linting
- [dragonlobster/wezterm-config](https://github.com/dragonlobster/wezterm-config) — clean single-file config with a great YouTube walkthrough
- [awesome-wezterm](https://github.com/michaelbrusegard/awesome-wezterm) — curated list of WezTerm plugins and resources
- [catppuccin/wezterm](https://github.com/catppuccin/wezterm) — official Catppuccin theme for WezTerm

## License

[MIT](LICENSE)
