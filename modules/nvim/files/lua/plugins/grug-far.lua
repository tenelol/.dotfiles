local plugin = require("nix-plugin")

return {
	plugin.spec("grug-far-nvim", {
		lazy = true,
		keys = {
			{
				"<leader>rr",
				function()
					local project = require("core.project")
					require("grug-far").open({
						prefills = { paths = project.buffer_root(0) },
					})
				end,
				mode = { "n", "x" },
				desc = "Find and replace in project",
			},
			{
				"<leader>rf",
				function()
					local project = require("core.project")
					local path = project.buffer_path(0)

					if path == nil then
						vim.notify("Save the buffer before opening file replace", vim.log.levels.WARN)
						return
					end

					require("grug-far").open({
						prefills = { paths = path },
					})
				end,
				desc = "Find and replace in current file",
			},
		},
		config = function()
			require("grug-far").setup({})
		end,
	}),
}
