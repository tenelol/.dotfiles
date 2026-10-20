local plugin = require("nix-plugin")

return {
	plugin.spec("grug-far-nvim", {
		cmd = { "GrugFar", "GrugFarWithin" },
		config = function()
			require("grug-far").setup({})
		end,
	}),
}
