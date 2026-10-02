local plugin = require("nix-plugin")
local theme = require("core.theme")

local function animate_scope()
	local ibl = require("ibl")
	local hooks = require("ibl.hooks")
	local animate = require("mini.animate")
	local states = {}

	hooks.register(hooks.type.SCOPE_HIGHLIGHT, function(tick, buf, scope, index)
		if buf ~= vim.api.nvim_get_current_buf() then
			states[buf] = nil
			return index
		end
		local state = states[buf]
		local changedtick = vim.api.nvim_buf_get_changedtick(buf)
		if state and state.id == scope:id() and state.changedtick == changedtick then
			state.tick = tick
			return index
		end
		local top, _, bottom = scope:range()
		top, bottom = math.max(top, vim.fn.line("w0") - 1), math.min(bottom, vim.fn.line("w$") - 1)
		state = { id = scope:id(), changedtick = changedtick, row = top - 1, tick = tick }
		states[buf] = state
		-- ponytail: cap at 12 redraws; raise only if large scopes look too coarse.
		local steps = math.min(12, bottom - top + 1)
		vim.schedule(function()
			animate.animate(function(step)
				if states[buf] ~= state then
					return false
				end
				if vim.api.nvim_get_current_buf() ~= buf or vim.api.nvim_buf_get_changedtick(buf) ~= changedtick then
					states[buf] = nil
					return false
				end
				state.row = step == steps and math.huge or top - 1 + math.ceil((bottom - top + 1) * step / steps)
				ibl.refresh(buf)
				return step < steps
			end, function()
				return 180 / steps
			end, { max_steps = steps })
		end)
		return index
	end)
	hooks.register(hooks.type.VIRTUAL_TEXT, function(tick, buf, row, text)
		local state = states[buf]
		if state and state.tick ~= tick then
			states[buf] = nil
			state = nil
		end
		if state and row > state.row then
			for _, chunk in ipairs(text) do
				for i, highlight in ipairs(chunk[2]) do
					if highlight:match("^@ibl%.scope%.char%.") then
						chunk[2][i] = "IblIndent"
					end
				end
			end
		end
		return text
	end)
	hooks.register(hooks.type.CLEAR, function(buf)
		states[buf] = nil
	end)
end

local function apply_highlights()
	vim.api.nvim_set_hl(0, "IblIndent", { fg = theme.ibl_indent })
	vim.api.nvim_set_hl(0, "IblScope", { fg = theme.ibl_scope })
	vim.api.nvim_set_hl(0, "IblWhitespace", { fg = theme.ibl_indent })
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
				scope = {
					highlight = "IblScope",
					show_start = false,
					show_end = false,
					include = { node_type = { nix = { "attrset_expression" } } },
				},
				whitespace = { highlight = "IblWhitespace" },
			})
			animate_scope()
		end,
	}),
}
