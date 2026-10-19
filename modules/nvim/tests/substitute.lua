-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/substitute.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.g.mapleader = " "
require("core.substitute").setup()

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- The word under the cursor matches whole words only, everywhere in the buffer.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo.bar foo foobar", "call foo()" })
vim.api.nvim_win_set_cursor(0, { 1, 8 })
feed(" rw<BS><BS><BS>baz<CR>")
assert(vim.deep_equal(lines(), { "baz.bar baz foobar", "call baz()" }), vim.inspect(lines()))

-- A selection is literal: dots, slashes, backslashes, & and ~ are plain text.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { [[a.b/c\d&e~ a.b/c\d&e~ axb/c\d&e~]] })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("v9l rw!<CR>")
assert(
  vim.deep_equal(lines(), { [[a.b/c\d&e~! a.b/c\d&e~! axb/c\d&e~]] }),
  "Selection replace was not literal: " .. vim.inspect(lines())
)

-- Text that looks like key notation stays literal.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "<CR> and <CR>" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("v3l rw<BS><BS><BS><BS>ok<CR>")
assert(vim.deep_equal(lines(), { "ok and ok" }), "Key notation leaked into the command: " .. vim.inspect(lines()))
print("Prefilled word and literal selection replace: OK")
