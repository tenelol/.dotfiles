local plugin = require("nix-plugin")

return {
  plugin.spec("diffview-nvim", {
    cmd = {
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewFocusFiles",
      "DiffviewOpen",
      "DiffviewToggleFiles",
    },
    dependencies = {
      plugin.dep("plenary-nvim"),
    },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Repository history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    },
    config = function()
      require("diffview").setup({
        enhanced_diff_hl = true,
      })
    end,
  }),

  plugin.spec("neogit", {
    cmd = "Neogit",
    dependencies = {
      plugin.dep("plenary-nvim"),
      plugin.dep("diffview-nvim"),
    },
    keys = {
      { "<leader>gs", "<cmd>Neogit<cr>", desc = "Git status" },
    },
    config = function()
      require("neogit").setup({
        graph_style = "unicode",
        integrations = {
          diffview = true,
        },
      })
    end,
  }),
}
