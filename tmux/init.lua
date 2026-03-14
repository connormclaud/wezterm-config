local core    = require("tmux.core")
local resolve = require("tmux.resolve")
local actions = require("tmux.actions")
local status  = require("tmux.status")

local M = {}

-- Core
M.bin    = core.bin
M.detect = core.detect
M.is_cc  = core.is_cc

-- Resolution
M.resolve_session = resolve.session
M.resolve_window  = resolve.window
M.resolve_pane    = resolve.pane
M.swap_window     = resolve.swap_window

-- Actions
M.kill_pane_action  = actions.kill_pane_action
M.rename_tab_action = actions.rename_tab_action
M.move_tab_action   = actions.move_tab_action

-- Status & keys
M.update_left_status = status.update_left_status
M.keys               = status.keys

return M
