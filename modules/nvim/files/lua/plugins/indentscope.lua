local plugin = require("nix-plugin")
local theme = require("core.theme")

local function apply_highlights()
  vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = theme.indent_scope, bold = true })
  vim.api.nvim_set_hl(0, "SnacksDim", { fg = theme.fg_dark })
end

return {
  plugin.spec("snacks-nvim", {
    event = { "BufReadPre", "BufNewFile" },
    keys = { { "<leader>ud", desc = "Toggle focus dimming" } },
    config = function()
      apply_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("IndentScopeHighlights", { clear = true }),
        callback = apply_highlights,
      })
      local snacks = require("snacks")
      snacks.setup({
        dim = {
          enabled = true,
          scope = {
            min_size = 2,
            cursor = false,
            treesitter = { enabled = false },
          },
          animate = {
            easing = "outQuad",
            duration = { step = 12, total = 180 },
          },
          filter = function(buf)
            return vim.g.snacks_dim ~= false
              and vim.b[buf].snacks_dim ~= false
              and vim.bo[buf].buftype == ""
              and vim.bo[buf].filetype ~= "dashboard"
          end,
        },
        indent = {
          enabled = true,
          filter = function(buf)
            return vim.g.snacks_indent ~= false
              and vim.b[buf].snacks_indent ~= false
              and vim.bo[buf].buftype == ""
              and vim.bo[buf].filetype ~= "dashboard"
          end,
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
      snacks.dim.enable()
      snacks.toggle.dim():map("<leader>ud")
    end,
  }),
}
