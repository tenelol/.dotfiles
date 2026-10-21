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
