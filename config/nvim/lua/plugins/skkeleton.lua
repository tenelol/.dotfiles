local plugin = require("nix-plugin")

local function load_dictionaries()
	local path = vim.fn.stdpath("config") .. "/skkeleton-dictionaries.lua"
	local ok, dictionaries = pcall(dofile, path)

	if ok and type(dictionaries) == "table" then
		return dictionaries.global_dictionaries or {}
	end

	return {}
end

local function configure_skkeleton()
	vim.fn["skkeleton#config"]({
		globalDictionaries = load_dictionaries(),
		userDictionary = vim.fn.expand("~/.skkeleton"),
		immediatelyDictionaryRW = true,
		keepMode = true,
	})
end

return {
	plugin.spec("skkeleton", {
		lazy = false,
		dependencies = {
			plugin.dep("denops-vim", {
				lazy = false,
				init = function()
					local deno = vim.fn.exepath("deno")

					if deno ~= "" then
						vim.g["denops#deno"] = deno
					end
				end,
			}),
		},
		config = function()
			local group = vim.api.nvim_create_augroup("SkkeletonConfig", { clear = true })

			vim.schedule(function()
				vim.fn["denops#server#connect_or_start"]()
			end)

			configure_skkeleton()

			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "skkeleton-initialize-pre",
				callback = configure_skkeleton,
			})

			vim.keymap.set({ "i", "c", "t" }, "<C-\\>", "<Plug>(skkeleton-toggle)", {
				silent = true,
				desc = "Toggle skkeleton",
			})
		end,
	}),
}
