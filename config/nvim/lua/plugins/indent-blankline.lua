local plugin = require("nix-plugin")
local theme = require("core.theme")

local function apply_highlights()
	vim.api.nvim_set_hl(0, "IblIndent", { fg = theme.fg_gutter })
	vim.api.nvim_set_hl(0, "IblScope", { fg = theme.blue })
	vim.api.nvim_set_hl(0, "IblWhitespace", { fg = theme.fg_gutter })
end

return {
	plugin.spec("indent-blankline-nvim", {
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			apply_highlights()

			vim.api.nvim_create_autocmd("ColorScheme", {
				group = vim.api.nvim_create_augroup("tokyonight_ibl_highlights", { clear = true }),
				callback = apply_highlights,
			})

			require("ibl").setup({
				indent = { highlight = "IblIndent" },
				scope = { highlight = "IblScope" },
				whitespace = { highlight = "IblWhitespace" },
			})
		end,
	}),
}
