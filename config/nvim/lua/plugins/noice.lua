local plugin = require("nix-plugin")

return {
  plugin.spec("noice-nvim", {
    event = "VeryLazy",
    opts = {},
    dependencies = {
      plugin.dep("nui-nvim"),
      plugin.dep("nvim-notify", {
        opts = {
          background_colour = "#000000",
        },
      }),
    },
  }),
}
