local plugin = require("nix-plugin")
local theme = require("core.theme")

return {
  plugin.spec("nvim-web-devicons", {
    lazy = false,
    priority = 900,
    config = function()
      require("nvim-web-devicons").setup({
        color_icons = false,
        default = true,
        override = {
          default_icon = {
            icon = "",
            color = theme.blue0,
            name = "Default",
          },
        },
      })
    end,
  }),
}
