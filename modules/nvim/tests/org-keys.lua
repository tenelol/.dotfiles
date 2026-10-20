-- Run from the repository root with the orgmode plugin directory:
-- ORGMODE=/nix/store/...-orgmode-... nvim --headless -u NONE -l modules/nvim/tests/org-keys.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.opt.runtimepath:prepend(assert(os.getenv("ORGMODE"), "set ORGMODE to the orgmode plugin directory"))
vim.g.mapleader = " "
package.loaded["nix-managed-plugins"] = setmetatable({}, {
	__index = function()
		return "/nonexistent"
	end,
})

local failures = {}
local function check(ok, message)
	if not ok then
		failures[#failures + 1] = message
	end
end

require("plugins.orgmode")[1].config()

for _, lhs in ipairs({ " a", " q" }) do
	check(vim.fn.maparg(lhs, "n") ~= "", ("global %q is mapped"):format(lhs))
end

local path = vim.fn.tempname() .. ".org"
vim.fn.writefile({ "* TODO 本を読む", "- [ ] 星の王子様" }, path)
vim.cmd.edit(path)
check(vim.bo.filetype == "org", "test buffer is an org buffer")

for _, lhs in ipairs({ " t", " x", " s", " d", " r" }) do
	local map = vim.fn.maparg(lhs, "n", false, true)
	check(map.buffer == 1 and map.nowait == 1, ("%q is buffer-local and nowait"):format(lhs))
end

local function press(lhs, line)
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	vim.fn.maparg(lhs, "n", false, true).callback()
end

press(" t", 1)
check(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "* DONE 本を読む", "<Leader>t advances the TODO state")
local checkbox = vim.fn.search("星の王子様", "n")
press(" x", checkbox)
check(vim.api.nvim_buf_get_lines(0, checkbox - 1, checkbox, false)[1] == "- [X] 星の王子様", "<Leader>x ticks the checkbox")

vim.cmd.enew()
check(vim.fn.maparg(" t", "n", false, true).buffer ~= 1, "the short keys stay out of other buffers")

-- Last, since the capture window takes over the layout. HOME is a scratch
-- directory, so whatever orgmode writes on exit stays out of ~/org.
-- <Leader>q opens a plain memo capture straight away, no template prompt.
vim.fn.maparg(" q", "n", false, true).callback()
-- The capture window opens on the next tick.
vim.wait(2000, function()
	return vim.b.org_capture ~= nil
end)
local capture = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check(capture[1] == "* " and (capture[2] or ""):match("^  %[%d%d%d%d%-%d%d%-%d%d .+ %d%d:%d%d%]$") ~= nil,
	"<Leader>q opens a plain memo with a creation stamp")

if #failures > 0 then
	io.stderr:write(table.concat(failures, "\n") .. "\n")
	vim.cmd.cquit(1)
end
print("org-keys: ok")
vim.cmd.quitall({ bang = true })
