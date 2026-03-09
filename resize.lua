local wezterm = require("wezterm")

local M = {}

local presets = { 0.25, 0.33, 0.50, 0.67, 0.75 }

local function detect_split(tab, active_id)
  local panes = tab:panes_with_info()
  if #panes < 2 then return nil end

  local active
  for _, p in ipairs(panes) do
    if p.pane:pane_id() == active_id then active = p; break end
  end
  if not active then return nil end

  for _, p in ipairs(panes) do
    if p.pane:pane_id() ~= active_id then
      if p.top == active.top and p.height == active.height then
        return "horizontal", panes, active
      end
      if p.left == active.left and p.width == active.width then
        return "vertical", panes, active
      end
    end
  end
  return nil
end

local function cycle_resize(window, pane)
  local tab = pane:tab()
  local axis, panes, active = detect_split(tab, pane:pane_id())
  if not axis then return end

  local total, current
  if axis == "horizontal" then
    total, current = 0, active.width
    local sep_count = 0
    for _, p in ipairs(panes) do
      if p.top == active.top then
        total = total + p.width
        if p.pane:pane_id() ~= pane:pane_id() then sep_count = sep_count + 1 end
      end
    end
    total = total + sep_count
  else
    total, current = 0, active.height
    local sep_count = 0
    for _, p in ipairs(panes) do
      if p.left == active.left then
        total = total + p.height
        if p.pane:pane_id() ~= pane:pane_id() then sep_count = sep_count + 1 end
      end
    end
    total = total + sep_count
  end

  local current_ratio = current / total

  local closest_idx = 1
  local min_diff = math.huge
  for i, r in ipairs(presets) do
    local diff = math.abs(current_ratio - r)
    if diff < min_diff then min_diff = diff; closest_idx = i end
  end
  local next_idx = (closest_idx % #presets) + 1
  local target = math.floor(total * presets[next_idx])
  local delta = target - current

  if delta == 0 then return end

  local direction
  if axis == "horizontal" then
    if active.left == 0 then
      direction = delta > 0 and "Right" or "Left"
    else
      direction = delta > 0 and "Left" or "Right"
    end
  else
    if active.top == 0 then
      direction = delta > 0 and "Down" or "Up"
    else
      direction = delta > 0 and "Up" or "Down"
    end
  end

  window:perform_action(
    wezterm.action.AdjustPaneSize({ direction, math.abs(delta) }),
    pane
  )
end

function M.keys()
  return {
    {
      key = "r",
      mods = "ALT",
      action = wezterm.action_callback(cycle_resize),
    },
  }
end

return M
