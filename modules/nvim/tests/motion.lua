-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/motion.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.o.columns, vim.o.lines = 100, 40
local motion = require("core.motion")
local panel = require("core.panel-motion")

local function floats()
  local list = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" and not config.hide then
      list[#list + 1] = win
    end
  end
  return list
end

-- Terminal splits keep their pty at full size while the window animates.
vim.cmd("botright 10split | enew")
local win = vim.api.nvim_get_current_win()
local buf = vim.api.nvim_get_current_buf()
vim.fn.jobstart({ "sh", "-c", "while :; do stty size; sleep 0.02; done" }, { term = true })
vim.wait(200)
local sizes = {}
local function sample()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i = #lines, 1, -1 do
    local rows = lines[i]:match("^(%d+) %d+")
    if rows then
      sizes[#sizes + 1] = tonumber(rows)
      return
    end
  end
end
vim.wo[win].wrap = true
vim.api.nvim_win_set_height(win, 10)
panel.open(win, { axis = "height", size = 10 })
assert(vim.api.nvim_win_get_height(win) < 10, "Panel must start collapsed")
local heights = {}
assert(vim.wait(1000, function()
  sample()
  heights[vim.api.nvim_win_get_height(win)] = true
  return not panel.is_active(win)
end, 10), "Panel open did not settle")
assert(vim.api.nvim_win_get_height(win) == 10, "Panel did not reach its size")
assert(vim.tbl_count(heights) > 3, "Panel snapped instead of growing")
for _, rows in ipairs(sizes) do
  assert(rows == 10, "Shell saw a resize mid-animation: " .. rows)
end

local reversed
panel.close(win, { axis = "height", on_done = function(completed) reversed = completed end })
vim.wait(60)
panel.open(win, { axis = "height", size = 10 })
assert(reversed == false, "Reopening must cancel the close")
assert(vim.wait(1000, function() return not panel.is_active(win) end, 10))
assert(vim.api.nvim_win_get_height(win) == 10 and vim.wo[win].wrap, "Reversal lost the size or wrap")
assert(not vim.w[win].dotfiles_panel_animation and not vim.w[win].edgy_disable, "Panel flags leaked")

-- Vertical panels clip instead of wrapping while narrower than the pty.
vim.cmd("wincmd L")
vim.api.nvim_win_set_width(win, 30)
panel.open(win, { axis = "width", size = 30 })
assert(vim.wo[win].wrap == false, "Narrow terminal should not wrap mid-animation")
assert(vim.wait(1000, function() return not panel.is_active(win) end, 10))
assert(vim.wo[win].wrap == true, "Wrap was not restored")

local closed
panel.close(win, { axis = "width", on_done = function(completed) closed = completed end })
assert(vim.wait(1000, function() return closed ~= nil end, 10), "Close never finished")
assert(closed == true and vim.api.nvim_win_get_width(win) <= 2, "Close did not collapse the panel")
assert(vim.wait(800, function() return #floats() == 0 end, 5), "Floats leaked")
print("Pinned pty, reversal, wrap clipping, and cleanup: OK")
