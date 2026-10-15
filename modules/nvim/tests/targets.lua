-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/targets.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
local targets = require("core.targets")
targets.setup()

local function brackets()
  local list = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" and config.zindex == 250 then
      list[#list + 1] = config
    end
  end
  return list
end

local function landed()
  -- Wait for the approach to finish, then read where the corners rest.
  vim.wait(200)
  local rows, cols = {}, {}
  for _, config in ipairs(brackets()) do
    rows[#rows + 1], cols[#cols + 1] = config.row, config.col
  end
  table.sort(rows)
  table.sort(cols)
  return rows, cols
end

local function settle()
  return vim.wait(1500, function()
    return #brackets() == 0
  end, 10)
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  vim.wait(0)
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha target beta", "gamma target delta", "target end" })

-- n keeps its count and locks onto the match it lands on.
vim.fn.setreg("/", "target")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("2n")
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 6 }), "Count was lost: " .. vim.inspect(vim.api.nvim_win_get_cursor(0)))
assert(#brackets() == 4, "Search jump should lock onto the match")
local rows, cols = landed()
-- "target" sits at screen row 1, columns 6-11; brackets land one cell outside.
assert(rows[1] == 0 and rows[4] == 2 and cols[1] == 5 and cols[4] == 11, "Match lock landed off target")
assert(settle(), "Match lock did not clean up")

-- A completed / search locks too; an aborted one does not.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("/delta<CR>")
vim.wait(20)
assert(#brackets() == 4, "Search command should lock onto the match")
assert(settle())
feed("/gamma<C-c>")
vim.wait(20)
assert(#brackets() == 0, "Aborted search must not lock")

-- Diagnostics lock onto their range.
local ns = vim.api.nvim_create_namespace("targets_test")
vim.diagnostic.set(ns, 0, { { lnum = 2, col = 7, end_lnum = 2, end_col = 10, message = "x", severity = 1 } })
vim.api.nvim_win_set_cursor(0, { 3, 7 })
targets.diagnostic()
rows, cols = landed()
-- The diagnostic adds a sign column, so measure where "end" is drawn now.
local start = vim.fn.screenpos(0, 3, 8).col - 1
assert(#rows == 4 and cols[1] == start - 1 and cols[4] == start + 2, "Diagnostic lock landed off its range: " .. vim.inspect({ rows, cols }))
assert(settle())

-- A new split locks onto itself; switching focus or opening a popup does not.
vim.cmd("vsplit")
vim.wait(30)
local fresh = vim.api.nvim_get_current_win()
local rect = require("core.motion").window_rect(fresh)
rows, cols = landed()
assert(#rows == 4 and cols[1] <= rect.col, "A new split should lock onto itself")
assert(settle())
feed("<C-w>l")
vim.wait(30)
assert(#brackets() == 0, "Switching focus must not frame the window")
local popup = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
  relative = "editor", row = 2, col = 2, width = 10, height = 2,
})
vim.wait(30)
assert(#brackets() == 0, "An unfocused popup must not frame the current window")
vim.api.nvim_win_close(popup, true)
vim.cmd("only")
vim.wait(30)
assert(#brackets() == 0, "Closing windows should not lock")
print("Search, command search, diagnostic and new-window locks, counts, and quiet focus switches: OK")
