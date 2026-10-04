-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/animate.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
package.loaded["nix-managed-plugins"] = { ["mini-animate"] = "/test/mini.animate" }
package.loaded["nix-plugin-modules"] = { "plugins.animate" }
package.loaded["features.web"] = {}
package.loaded["features.platformio"] = {}
require("core.plugin-loader")
assert(_G.MiniAnimate == nil, "Animations should wait for VeryLazy")
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })

local animate = require("mini.animate")
for _, action in ipairs({ "cursor", "resize", "open", "close" }) do
  assert(animate.config[action].enable, action .. " animation is disabled")
end
assert(not animate.config.scroll.enable, "MiniAnimate must leave scrolling to Neoscroll")
assert(animate.config.cursor.timing(1, 30) < animate.config.cursor.timing(30, 30), "Cursor should ease out")
assert(#animate.config.cursor.path({ 100, 100 }) <= 30, "Long cursor jumps need a bounded path")
assert(#animate.config.cursor.path({ 0, 8 }) > 0, "Word jumps should show a cursor trail")
assert(#animate.config.cursor.path({ 0, 1 }) == 0, "Typing should not flash a cursor trail")

local lines = {}
for i = 1, 200 do
  lines[i] = "Line " .. i
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_exec_autocmds("BufEnter", {})
vim.cmd("normal! ggzt")
vim.api.nvim_exec_autocmds("WinScrolled", {})
vim.cmd("normal! 50Gzt")
local target = vim.fn.winsaveview()
vim.api.nvim_exec_autocmds("WinScrolled", {})
assert(not animate.is_active("scroll"), "MiniAnimate started a second scroll animation")
assert(vim.fn.winsaveview().topline == target.topline, "Animation changed the scroll destination")
assert(vim.fn.line(".") == target.lnum, "Animation changed the cursor destination")
local function check_animation(action, command)
  local finished = false
  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniAnimateDone" .. action,
    once = true,
    callback = function() finished = true end,
  })
  vim.cmd(command)
  vim.api.nvim_exec_autocmds("WinScrolled", {})
  assert(vim.wait(1000, function() return finished end), action .. " animation did not finish")
end
check_animation("Open", "vsplit")
local width = vim.api.nvim_win_get_width(0) - 5
check_animation("Resize", "vertical resize " .. width)
assert(vim.api.nvim_win_get_width(0) == width, "Resize changed the target width")
check_animation("Close", "close")
assert(#vim.api.nvim_list_wins() == 1, "Animation window leaked")
print("Cursor easing, single scroll provider, window animations, and final layout: OK")
