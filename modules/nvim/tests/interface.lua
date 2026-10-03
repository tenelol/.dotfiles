-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/interface.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.g.mapleader = " "
vim.o.winbar = " "
local failures = {}
local function check(ok, message)
	if not ok then
		failures[#failures + 1] = message
	end
end

local available, location = false, ""
package.loaded["nvim-navic"] = {
	setup = function() end,
	is_available = function()
		return available
	end,
	get_location = function()
		return location
	end,
}
vim.api.nvim_buf_set_name(0, "/tmp/interface%test.lua")
require("plugins.lualine")[1].config()
local lualine = require("lualine")
local plain = lualine.winbar()
available, location = true, "Outer > Inner"
local symbols = lualine.winbar()
available, location = false, ""
local empty = lualine.winbar()
available = true
local outside = lualine.winbar()
check(plain ~= "" and empty ~= "", "Breadcrumb row disappears without LSP symbols")
check(outside == empty, "Breadcrumb row disappears outside a symbol")
vim.wo.winbar = plain
local height = vim.fn.winheight(0)
vim.wo.winbar = symbols
check(vim.fn.winheight(0) == height, "Breadcrumb symbols changed the editing area height")
vim.wo.winbar = empty
check(vim.fn.winheight(0) == height, "Missing breadcrumbs changed the editing area height")
check(symbols:find("Outer > Inner", 1, true) ~= nil, "Breadcrumb symbols are missing")
check(plain:find("interface%%test.lua", 1, true) ~= nil, "Fallback filename must escape statusline percent signs")
local before_open = vim.fn.winheight(0)
local fresh = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(fresh, "/tmp/new-breadcrumb-test.nix")
vim.api.nvim_win_set_buf(0, fresh)
check(vim.fn.winheight(0) == before_open, "Opening a fresh buffer changed the reserved breadcrumb row")
lualine.refresh({ scope = "window", place = { "winbar" }, force = true })
check(vim.fn.winheight(0) == before_open, "First breadcrumb refresh moved the editing area")

local enable = vim.lsp.enable
vim.lsp.enable = function() end
require("plugins.language-server")[1].config()
vim.lsp.enable = enable
local settings = vim.lsp.config.nil_ls.settings or {}
local flake = (settings["nil"] or {}).nix or {}
check((flake.flake or {}).autoArchive == true, "nil must fetch missing flake inputs instead of ignoring them")

require("plugins.neotree")[1].config()
local state = require("neo-tree.sources.manager").get_state("filesystem")
check(state.find_by_full_path_words == true, "Neo-tree cannot match directory and file names together")
check(state.window.mappings["/"] == "fuzzy_finder", "Neo-tree needs a file fuzzy-search shortcut")
check(state.window.mappings["f"] == "filter_as_you_type", "Neo-tree needs a recursive tree filter")

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/src/nested", "p")
local filename = root .. "/src/nested/target.lua"
vim.fn.writefile({ "return true" }, filename)
local found, exit_code = {}, nil
require("neo-tree.sources.filesystem.lib.filter_external").find_files({
	path = root,
	term = "src nested target",
	find_by_full_path_words = state.find_by_full_path_words,
	filtered_items = state.filtered_items,
	on_insert = function(err, path)
		if not err then
			found[#found + 1] = path
		end
	end,
	on_exit = function(code)
		exit_code = code
	end,
})
local finished = vim.wait(2000, function()
	return exit_code ~= nil
end)
vim.fn.delete(root, "rf")
check(
	finished and exit_code == 0 and vim.tbl_contains(found, filename),
	"Neo-tree recursive search missed a nested file"
)
assert(#failures == 0, table.concat(failures, "\n"))
print("Breadcrumb fallback, nil prompts, and Neo-tree search configuration: OK")
