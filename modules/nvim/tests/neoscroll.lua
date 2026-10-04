-- Run with nvim --headless -u NONE -l modules/nvim/tests/neoscroll.lua.
-- Before activation, set NVIM_NEOSCROLL_TEST_RUNTIME to the pinned plugin checkout.
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
local runtime = os.getenv("NVIM_NEOSCROLL_TEST_RUNTIME")
if runtime then
  vim.opt.runtimepath:append(runtime)
end
local paths = require("nix-managed-plugins")
paths["neoscroll-nvim"] = paths["neoscroll-nvim"] or runtime
require("plugins.animate")[1].config()
require("plugins.neoscroll")[1].config()
local scroll = require("neoscroll.scroll")
vim.o.termguicolors = true
vim.o.scrolloff = 8
local original_cursor = vim.o.guicursor
local original_events = vim.o.eventignore
local refreshed = false
vim.api.nvim_create_autocmd("CursorMoved", {
  callback = function()
    refreshed = true
  end,
})

local lines = {}
for i = 1, 300 do
  lines[i] = "Line " .. i
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.cmd("normal! 80Gzz")

local function mapped(key)
  local mapping = vim.fn.maparg(key, "n", false, true)
  assert(type(mapping.callback) == "function", "Missing smooth scroll mapping: " .. key)
  mapping.callback()
end

local function settle()
  assert(vim.wait(1500, function()
    return not scroll.scrolling
  end, 2), "Scrolling did not finish")
  assert(vim.wait(100, function()
    return refreshed
  end, 2), "Scopes and breadcrumbs were not refreshed after scrolling")
  assert(vim.o.eventignore == original_events, "Movement events stayed disabled")
  assert(vim.o.guicursor == original_cursor, "Cursor stayed hidden")
  assert(not require("mini.animate").is_active("scroll"), "Two scroll providers ran together")
end

local start = vim.fn.winsaveview()
local half = vim.wo.scroll
refreshed = false
mapped("<C-d>")
assert(scroll.scrolling, "Half-page scroll jumped immediately")
local intermediate = false
assert(vim.wait(1000, function()
  local top = vim.fn.line("w0")
  intermediate = intermediate or (top > start.topline and top < start.topline + half)
  return not scroll.scrolling
end, 2))
settle()
assert(intermediate, "Half-page scrolling had no intermediate positions")
assert(vim.fn.line(".") == start.lnum + half, "Half-page scrolling changed the cursor destination")
assert(vim.fn.line("w0") == start.topline + half, "Half-page scrolling changed the viewport destination")

refreshed = false
mapped("<C-u>")
settle()
assert(vim.fn.line(".") == start.lnum and vim.fn.line("w0") == start.topline, "Reverse scrolling did not return")

refreshed = false
mapped("<C-d>")
mapped("<C-d>")
mapped("<C-d>")
settle()
assert(vim.fn.line(".") == start.lnum + half * 3, "Repeated scrolls lost movement")

for _, key in ipairs({ "<C-f>", "<C-b>", "<C-e>", "<C-y>", "zt", "zz", "zb" }) do
  refreshed = false
  mapped(key)
  settle()
end
vim.cmd("normal! Gzz")
mapped("<C-d>")
settle()
assert(vim.fn.line(".") == #lines and not scroll.scrolling, "Scrolling stuck at end of file")
print("Neoscroll intermediate positions, repeated input, restored events/cursor, and MiniAnimate coordination: OK")
