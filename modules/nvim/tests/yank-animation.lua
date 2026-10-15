-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/yank-animation.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
require("core.yank-animation").setup()
local ns = vim.api.nvim_get_namespaces().dotfiles_yank_sweep

local function marks()
  return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
end

local function wait_done()
  return vim.wait(1000, function()
    return #marks() == 0
  end, 10)
end

for level = 1, 8 do
  assert(vim.api.nvim_get_hl(0, { name = "YankSweep" .. level }).bg, "Missing sweep level " .. level)
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha 日本語 beta", "gamma delta", "", "epsilon" })

-- Charwise yank across multibyte text: the head lights the first cell first.
vim.api.nvim_win_set_cursor(0, { 1, 6 })
vim.cmd("normal! y3l")
assert(vim.wait(200, function()
  return #marks() > 0
end, 5), "Charwise yank did not animate")
local first = marks()[1]
assert(first[2] == 0 and first[3] == 6, "Sweep should start at the yank start")
assert(first[4].hl_group == "YankSweep1", "Fresh cells should be white-hot")
local last_col = 0
assert(vim.wait(200, function()
  for _, mark in ipairs(marks()) do
    last_col = math.max(last_col, mark[4].end_col)
  end
  if last_col > 15 then
    error("Sweep ran past the yank end: " .. last_col)
  end
  return last_col == 15
end, 5), "Sweep should reach the end of the multibyte yank")
assert(vim.wait(400, function()
  local mark = marks()[1]
  return mark and mark[3] == 6 and mark[4].hl_group ~= "YankSweep1"
end, 5), "Lit cells should cool after the head passes")
assert(wait_done(), "Charwise sweep did not clean up")

-- Linewise yank spanning an empty line.
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("normal! yj")
local rows = {}
assert(vim.wait(1000, function()
  local current = marks()
  for _, mark in ipairs(current) do
    rows[mark[2]] = true
  end
  return rows[1] ~= nil and #current == 0
end, 5), "Linewise sweep did not finish")
assert(rows[2] == nil, "Empty lines have no cells to light")

-- Blockwise regtype carries a width suffix.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("normal! \22jly")
assert(vim.wait(200, function()
  return #marks() > 0
end, 5), "Blockwise yank did not animate")
assert(vim.wait(1000, function()
  for _, mark in ipairs(marks()) do
    assert(mark[4].end_row == mark[2] and mark[4].end_col <= 2, "Block sweep left its columns")
  end
  return #marks() == 0
end, 5), "Blockwise sweep did not clean up")

-- Deletes reuse TextYankPost but must not flash removed text.
vim.cmd("normal! ggdw")
vim.wait(60)
assert(#marks() == 0, "Delete should not animate")

-- Huge yanks stay bounded per frame.
local lines = {}
for i = 1, 400 do
  lines[i] = ("line %d with some text"):format(i)
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.cmd("normal! ggyG")
local peak = 0
assert(vim.wait(1000, function()
  peak = math.max(peak, #marks())
  return peak > 0 and #marks() == 0
end, 5), "Huge sweep did not finish")
assert(peak <= 96, "Huge sweep drew too many marks per frame: " .. peak)

-- A new yank replaces the running sweep instead of stacking timers.
vim.cmd("normal! ggyy")
vim.cmd("normal! Gyy")
vim.wait(30)
for _, mark in ipairs(marks()) do
  assert(mark[2] == 399, "Previous sweep leaked into the new one")
end
assert(wait_done(), "Replacement sweep did not clean up")
print("Yank sweep ordering, cooling, regtypes, delete skip, bounds, and cleanup: OK")
