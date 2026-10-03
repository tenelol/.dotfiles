local plugin = require("nix-plugin")
local theme = require("core.theme")

local function apply_highlights()
  vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = theme.indent_scope, bold = true })
end

return {
  plugin.spec("snacks-nvim", {
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      apply_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("IndentScopeHighlights", { clear = true }),
        callback = apply_highlights,
      })
      local snacks = require("snacks")
      snacks.setup({
        indent = {
          enabled = true,
          indent = { enabled = false },
          scope = {
            only_current = true,
            char = "┃",
            cursor = false,
            treesitter = { enabled = false },
          },
          animate = {
            style = "down",
            easing = "linear",
            duration = { step = 20, total = 300 },
          },
        },
      })
      snacks.indent.enable()
    end,
  }),
}
