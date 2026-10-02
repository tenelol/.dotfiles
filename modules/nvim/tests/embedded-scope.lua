-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/embedded-scope.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.bo.filetype = "astro"
vim.bo.shiftwidth = 2
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
	"---",
	"const title = 'Demo';",
	"---",
	'<html lang="en">',
	"  <head>",
	"    <style>",
	"      ul {",
	"        display: flex;",
	"        gap: 2rem;",
	"        list-style-type: none;",
	"      }",
	"    </style>",
	"  </head>",
	"</html>",
})
vim.api.nvim_win_set_cursor(0, { 10, 14 })
vim.treesitter.start(0)
vim.treesitter.get_parser(0):parse(true)
local completed = false
local animate = require("mini.animate")
local original = animate.animate
animate.animate = function(callback, timing, opts)
	original(function(step)
		local more = callback(step)
		if step == opts.max_steps then
			completed = true
		end
		return more
	end, timing, opts)
end
require("plugins.indent-blankline")[1].config()
require("ibl").refresh(0)
assert(
	vim.wait(1000, function()
		return completed
	end),
	"Astro CSS scope animation never starts"
)
local rows = {}
for _, mark in
	ipairs(
		vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("indent_blankline"), 0, -1, { details = true })
	)
do
	for _, chunk in ipairs(mark[4].virt_text or {}) do
		if
			chunk[2] == "@ibl.scope.char.1"
			or (type(chunk[2]) == "table" and vim.tbl_contains(chunk[2], "@ibl.scope.char.1"))
		then
			rows[#rows + 1] = mark[2]
		end
	end
end
assert(vim.deep_equal(rows, { 7, 8, 9 }), "Wrong Astro CSS scope: " .. vim.inspect(rows))
completed = false
vim.api.nvim_buf_set_lines(0, 5, 6, false, { '    <style lang="scss">' })
vim.treesitter.get_parser(0):parse(true)
require("ibl").refresh(0)
assert(
	vim.wait(1000, function()
		return completed
	end),
	"Astro SCSS scope animation never starts"
)
local scope = require("ibl.scope").get(vim.api.nvim_get_current_buf(), require("ibl.config").get_config(0))
assert(scope and scope:type() == "block", "Astro SCSS must select its style block")
print("Astro embedded CSS and SCSS scope highlighting: OK")
