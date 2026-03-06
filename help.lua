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
    header = "── Tabs / Panes ──────────────────────────────────────────────────────",
    items = {
      { "Ctrl+Shift+T",    "New tab" },
      { "Ctrl+Shift+D",    "Split horizontal" },
      { "Ctrl+Shift+W",    "Close tab" },
      { "Ctrl+Shift+E",    "Split vertical" },
      { "Ctrl+Tab",        "Next tab" },
      { "Ctrl+Shift+Arrow", "Navigate panes" },
      { "Ctrl+Shift+Tab",  "Previous tab" },
      { "Ctrl+Shift+Z",    "Toggle pane zoom" },
      { "Ctrl+Shift+1..9", "Go to tab N" },
      { "Ctrl+Shift+K",    "Kill current pane" },
      { "Ctrl+Shift+O",    "Pane select (jump)" },
      { "F2",              "Rename tab / tmux window" },
    },
  },
  {
    header = "── Scrollback / Copy ─────────────────────────────────────────────────",
    items = {
      { "Shift+PgUp/Down",  "Scroll up/down" },
      { "Ctrl+Shift+C",     "Copy selection" },
      { "Ctrl+Shift+F",     "Search" },
      { "Ctrl+Shift+V",     "Paste clipboard" },
      { "Ctrl+Shift+X",     "Activate copy mode" },
    },
  },
  {
    header = "── Font / Debug / Custom ─────────────────────────────────────────────",
    items = {
      { "Ctrl+= / Ctrl+-",  "Inc / dec font" },
      { "Ctrl+Shift+A",     "Attach tmux session" },
      { "Ctrl+0",           "Reset font size" },
      { "Ctrl+Shift+H",     "Toggle health reminder" },
      { "Ctrl+Shift+L",     "Debug overlay" },
      { "F1",               "This cheat sheet" },
      { "Ctrl+Shift+R",     "Reload config" },
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
