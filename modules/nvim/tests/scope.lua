-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/scope.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.bo.filetype = "lua"
vim.bo.shiftwidth = 2
local lines = { "local function outer()", "  if true then" }
for i = 1, 12 do
	lines[#lines + 1] = '    print("' .. i .. '")'
end
vim.list_extend(lines, { "  end", "end" })
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_win_set_cursor(0, { 12, 4 })
vim.treesitter.get_parser(0):parse()

local animate = require("mini.animate")
local original = animate.animate
local action, steps
animate.animate = function(callback, _, opts)
	action, steps = callback, opts.max_steps
end
require("plugins.indent-blankline")[1].config()
assert(vim.api.nvim_get_hl(0, { name = "IblScope" }).fg == 0x9EABC0, "Scope line must use muted silver")
assert(vim.api.nvim_get_hl(0, { name = "IblScopeHead" }).fg == 0xC8D3E0, "Animation head must use a soft highlight")
assert(require("ibl.config").get_config(0).scope.char == "┃", "Scope line must be thicker")
require("ibl").refresh(0)
assert(
	vim.wait(1000, function()
		return action ~= nil
	end),
	"Scope animation was not started"
)

local function highlighted_rows()
	local rows = {}
	local ns = vim.api.nvim_create_namespace("indent_blankline")
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
		for _, chunk in ipairs(mark[4].virt_text or {}) do
			if
				chunk[2] == "@ibl.scope.char.1"
				or (type(chunk[2]) == "table" and vim.tbl_contains(chunk[2], "@ibl.scope.char.1"))
			then
				rows[#rows + 1] = mark[2]
			end
		end
	end
	return rows
end

action(0)
assert(#highlighted_rows() == 0, "Scope was highlighted before animation began")
assert(action(math.floor(steps / 2)), "Animation stopped halfway")
local middle = highlighted_rows()
local head_rows = {}
for _, mark in
	ipairs(
		vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("indent_blankline"), 0, -1, { details = true })
	)
do
	for _, chunk in ipairs(mark[4].virt_text or {}) do
		if chunk[2] == "IblScopeHead" or (type(chunk[2]) == "table" and vim.tbl_contains(chunk[2], "IblScopeHead")) then
			head_rows[#head_rows + 1] = mark[2]
		end
	end
end
assert(#head_rows == 1 and head_rows[1] > middle[#middle], "Bright head must lead the filled scope line")
assert(#middle > 0 and middle[1] == 2, "Scope must light up from its top, not the cursor")
assert(middle[#middle] < 11, "Lower lines lit up before animation reached them")
assert(not action(steps), "Animation must stop at its final frame")
local final = highlighted_rows()
assert(#final > #middle and final[#final] == 13, "Scope did not fill to its bottom")

local other = vim.api.nvim_create_buf(false, true)
local original_buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_set_current_buf(other)
assert(not action(1), "Animation must stop after switching buffers")
local completed = false
animate.animate = function(callback, timing, opts)
	original(function(step)
		local more = callback(step)
		if step == opts.max_steps then
			completed = true
		end
		return more
	end, timing, opts)
end
vim.api.nvim_set_current_buf(original_buffer)
require("ibl").refresh(0)
assert(
	vim.wait(1000, function()
		return completed and #highlighted_rows() == #final
	end),
	"Real animation timer did not complete"
)
print("Top-to-bottom scope highlighting and buffer-switch cancellation: OK")
