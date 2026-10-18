-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/quit.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.o.hidden = true
local spec = require("plugins.edgy")[1]
spec.init()
spec.config()
require("plugins.neotree")[1].config()

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
vim.fn.writefile({ "example" }, directory .. "/example.txt")
vim.cmd("edit " .. vim.fn.fnameescape(directory .. "/example.txt"))
local main = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })

-- Open the tree as an Edgy panel and a second, unmanaged one on the right.
require("neo-tree.command").execute({ source = "filesystem", dir = directory, position = "left" })
require("neo-tree.command").execute({ source = "git_status", dir = directory, position = "right" })
assert(vim.wait(1500, function()
  return not require("core.panel-motion").is_active() and #vim.api.nvim_list_wins() >= 3
end, 10), "Panels did not open")
vim.api.nvim_set_current_win(main)

local errors = {}
vim.notify = function(message, level)
  if level and level >= vim.log.levels.WARN then
    errors[#errors + 1] = message
  end
end

local ok, err = pcall(vim.cmd, "quit")
vim.wait(300)
assert(not ok and tostring(err):find("E37", 1, true), "Unsaved :q should refuse with E37, got: " .. tostring(err))
assert(vim.api.nvim_win_is_valid(main), "The edited window was closed")
local plain = vim.tbl_filter(function(win)
  return vim.api.nvim_win_get_config(win).relative == ""
end, vim.api.nvim_list_wins())
assert(#plain == 1, "Quitting with unsaved changes must not reopen splits: " .. #plain)
assert(#errors == 0, "Quitting should not surface plugin errors: " .. vim.inspect(errors))

vim.fn.delete(directory, "rf")
print("Unsaved :q keeps one window with Vim's E37 and no extra splits: OK")
