-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/panels.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
require("plugins.animate")[1].config()
local spec = require("plugins.edgy")[1]
spec.init()
spec.config()
local edgy = require("edgy")
local animation = require("edgy.animate")
local main = vim.api.nvim_get_current_win()

local tree = vim.api.nvim_create_buf(false, true)
vim.bo[tree].filetype = "neo-tree"
vim.b[tree].neo_tree_source = "filesystem"
vim.cmd("topleft vsplit")
local tree_window = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(tree_window, tree)
local intermediate = false
assert(vim.wait(1500, function()
  local width = vim.api.nvim_win_get_width(tree_window)
  intermediate = intermediate or (animation.is_active() and width > 1 and width < 34)
  return edgy.get_win(tree_window) and width == 34 and not animation.is_active()
end, 10), "Sidebar animation did not settle")
assert(intermediate, "Sidebar snapped open without sliding")
assert(vim.g.minianimate_disable == false, "MiniAnimate stayed disabled after sidebar animation")
vim.api.nvim_win_close(tree_window, true)
vim.api.nvim_set_current_win(main)
vim.wait(300, function() return false end)

local terminal = vim.api.nvim_create_buf(false, true)
vim.cmd("botright 10new")
local terminal_window = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(terminal_window, terminal)
vim.api.nvim_open_term(terminal, {})
vim.bo[terminal].filetype = "toggleterm"
assert(vim.wait(1500, function()
  return edgy.get_win(terminal_window) and vim.api.nvim_win_get_height(terminal_window) == 10 and not animation.is_active()
end, 10), "Terminal layout did not settle")
assert(vim.g.minianimate_disable == false, "MiniAnimate stayed disabled after terminal layout")
vim.api.nvim_win_close(terminal_window, true)
vim.api.nvim_set_current_win(main)

vim.o.termguicolors = true
require("plugins.noice")[1].config()
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(vim.wait(1000, function()
  return require("noice.config").options.routes ~= nil
end), "Noice did not initialize")
local notify = require("notify")._config()
assert(notify.fps() == 60 and notify.stages() == "fade_in_slide_out")
local animated_info = false
for _, route in ipairs(require("noice.config").options.routes) do
  if route.filter.event == "notify" and route.filter.kind == "info" then
    animated_info = route.view == "notify"
  end
end
assert(animated_info, "Info notifications must use the animated view")
io.write("Sidebar slide, terminal layout, animated notifications, and MiniAnimate coordination: OK\n")
