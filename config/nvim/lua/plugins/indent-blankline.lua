local plugin = require("nix-plugin")

return {
	plugin.spec("indent-blankline-nvim", {
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("ibl").setup({})
		end,
	}),
}
