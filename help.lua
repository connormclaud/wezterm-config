local wezterm = require("wezterm")

local M = {}

local function pad_right(s, w)
  local n = w - #s
  return n > 0 and s .. string.rep(" ", n) or s
end

local function format_columns(sections)
  local choices = {}
  local key_w, entry_w = 0, 0
  for _, sec in ipairs(sections) do
    for _, item in ipairs(sec.items) do
      key_w = math.max(key_w, #item[1])
      entry_w = math.max(entry_w, #item[1] + 2 + #item[2])
    end
  end
  entry_w = entry_w + 4

  for _, sec in ipairs(sections) do
    table.insert(choices, { label = sec.header })
    for i = 1, #sec.items, 2 do
      local a, b = sec.items[i], sec.items[i + 1]
      local left = pad_right(a[1], key_w + 2) .. a[2]
      if b then
        left = pad_right(left, entry_w) .. pad_right(b[1], key_w + 2) .. b[2]
      end
      table.insert(choices, { label = left })
    end
  end
  return choices
end

local choices = format_columns({
  {
    header = "── Panes ─────────────────────────────────────────────────────────────",
    items = {
      { "Ctrl+Shift+D",        "Split horizontal" },
      { "Ctrl+Shift+K",        "Kill current pane" },
      { "Ctrl+Shift+E",        "Split vertical" },
      { "Alt+R",               "Cycle pane size (25/33/50/67/75%)" },
    },
  },
  {
    header = "── Tabs ──────────────────────────────────────────────────────────────",
    items = {
      { "F2",                  "Rename tab / tmux window" },
      { "Shift+Enter",        "Newline (Ctrl+J, tmux-safe)" },
      { "Ctrl+Shift+PgUp/Dn", "Move tab left / right" },
      { "Ctrl+Shift+A",       "Tmux session manager" },
      { "Ctrl+Shift+G",       "Open/close Claude agent tabs" },
    },
  },
  {
    header = "── Toggles ───────────────────────────────────────────────────────────",
    items = {
      { "Ctrl+Shift+H",       "Toggle health reminder" },
      { "F1",                  "This cheat sheet" },
    },
  },
})

function M.keys()
  local act = wezterm.action
  return {
    {
      key = "F1",
      action = act.InputSelector({
        title = "WezTerm Keybindings",
        choices = choices,
        action = wezterm.action_callback(function() end),
      }),
    },
  }
end

return M
