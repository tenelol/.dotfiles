local plugin = require("nix-plugin")

return {
  plugin.spec("noice-nvim", {
    event = "VeryLazy",
    config = function()
      require("noice").setup({})
    end,
    dependencies = {
      plugin.dep("nui-nvim"),
      plugin.dep("nvim-notify", {
        config = function()
          require("notify").setup({
            background_colour = "#000000",
          })
        end,
      }),
    },
  }),
}
