-- From the repository root:
-- nvim --headless -u NONE --cmd 'set rtp+=/path/to/mini.animate' -l modules/nvim/tests/animate.lua
vim.opt.runtimepath:append(vim.fn.getcwd() .. "/modules/nvim/files")
package.loaded["nix-managed-plugins"] = { ["mini-animate"] = "/test/mini.animate" }
package.loaded["nix-plugin-modules"] = { "plugins.animate" }
package.loaded["features.web"] = {}
package.loaded["features.platformio"] = {}
require("core.plugin-loader")
assert(_G.MiniAnimate == nil, "Animations should wait for VeryLazy")
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })

local animate = require("mini.animate")
for _, action in ipairs({ "cursor", "scroll", "resize", "open", "close" }) do
  assert(animate.config[action].enable, action .. " animation is disabled")
end
assert(animate.config.cursor.timing(1, 10) == 15)
assert(animate.config.scroll.timing(1, 1) == 10, "Single-line scroll must stay responsive")
assert(animate.config.scroll.timing(1, 30) == 5, "Large scroll must fit within 150ms")

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
local done = false
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniAnimateDoneScroll",
  once = true,
  callback = function() done = true end,
})
vim.api.nvim_exec_autocmds("WinScrolled", {})
assert(vim.wait(1000, function() return done end), "Scroll animation did not finish")
assert(vim.fn.winsaveview().topline == target.topline, "Animation changed the scroll destination")
assert(vim.fn.line(".") == target.lnum, "Animation changed the cursor destination")
print("Animation loading, timing, and scroll destination: OK")
