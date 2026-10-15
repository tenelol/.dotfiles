-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/yank-animation.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
require("core.yank-animation").setup()
local ns = vim.api.nvim_get_namespaces().dotfiles_yank_lock

local function marks()
  return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
end

local function brackets()
  local list = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      list[#list + 1] = vim.api.nvim_win_get_config(win)
    end
  end
  return list
end

local function yank(keys)
  vim.cmd("normal! " .. keys)
  -- The lock starts on the next event-loop tick.
  vim.wait(0)
end

local function settle()
  return vim.wait(1500, function()
    return #marks() == 0 and #brackets() == 0
  end, 10)
end

for level = 1, 8 do
  assert(vim.api.nvim_get_hl(0, { name = "YankLock" .. level }).bg, "Missing lock level " .. level)
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha 日本語 beta", "gamma delta", "", "epsilon" })

-- Charwise yank: faint tint while the brackets aim, flash at contact, then cool.
vim.api.nvim_win_set_cursor(0, { 1, 6 })
yank("y3l")
local mark = marks()[1]
assert(mark and mark[2] == 0 and mark[3] == 6 and mark[4].end_col == 15, "Yank tint should cover the multibyte yank")
assert(mark[4].hl_group == "YankLock8", "The region stays faint until the lock lands")
assert(#brackets() == 4, "Yank should launch the lock-on brackets")
local rows, cols = {}, {}
local flashed = false
assert(vim.wait(500, function()
  local current = marks()[1]
  if current and current[4].hl_group == "YankLock1" then
    flashed = true
    for _, config in ipairs(brackets()) do
      rows[config.row] = true
      cols[config.col] = true
    end
  end
  return flashed
end, 2), "The yank never flashed on lock")
-- Brackets land one row above/below and one cell outside the yanked text.
assert(rows[-1] == nil and rows[0] and rows[1] and cols[5], "Brackets landed off the yanked text")
assert(settle(), "Yank lock did not clean up")

-- Linewise yank spanning an empty line paints one contiguous mark.
vim.api.nvim_win_set_cursor(0, { 2, 0 })
yank("yj")
local line_mark = marks()[1]
-- The end may be normalized from the end of row 1 to the start of row 2.
assert(#marks() == 1 and line_mark[2] == 1 and (line_mark[4].end_row == 1 or line_mark[4].end_col == 0),
  "Linewise yank should be one mark ending on the last text row")
assert(settle(), "Linewise lock did not clean up")

-- Blockwise regtype carries a width suffix and paints per line.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
yank("\22jly")
assert(#marks() == 2, "Blockwise yank should paint each row")
for _, block in ipairs(marks()) do
  assert(block[4].end_row == block[2] and block[4].end_col <= 2, "Block paint left its columns")
end
assert(settle(), "Blockwise lock did not clean up")

-- Deletes reuse TextYankPost but must not flash removed text.
yank("ggdw")
assert(#marks() == 0 and #brackets() == 0, "Delete should not animate")

-- Huge yanks stay one mark and the brackets frame only the visible part.
local lines = {}
for i = 1, 400 do
  lines[i] = ("line %d with some text"):format(i)
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
yank("ggyG")
assert(#marks() == 1, "Huge yank should be a single mark")
for _, config in ipairs(brackets()) do
  assert(config.row < vim.o.lines, "Brackets left the screen")
end
assert(settle(), "Huge lock did not clean up")

-- A new yank replaces the running one.
vim.cmd("normal! ggyy")
vim.cmd("normal! jyy")
vim.wait(20)
for _, current in ipairs(marks()) do
  assert(current[2] == 1, "Previous yank paint leaked into the new one")
end
assert(settle(), "Replacement lock did not clean up")
print("Yank lock aiming, flash, cooling, regtypes, delete skip, bounds, and cleanup: OK")
