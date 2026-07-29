local plugin = require("nix-plugin")

return {
  plugin.spec("edgy-nvim", {
    event = "VeryLazy",
    init = function()
      vim.opt.splitkeep = "screen"
    end,
    config = function()
      require("edgy").setup({
        left = {
          {
            ft = "neo-tree",
            filter = function(buf)
              return vim.b[buf].neo_tree_source == "filesystem"
            end,
          },
        },
        bottom = {
          {
            ft = "toggleterm",
            size = { height = 10 },
            filter = function(_, win)
              return vim.api.nvim_win_get_config(win).relative == ""
            end,
          },
        },
        options = {
          left = { size = 34 },
          bottom = { size = 10 },
        },
        animate = {
          enabled = false,
        },
        close_when_all_hidden = true,
        wo = {
          winbar = false,
          winfixwidth = true,
          winfixheight = false,
          winhighlight = "",
          spell = false,
          signcolumn = "no",
          scrolloff = 0,
        },
      })
    end,
  }),
}
