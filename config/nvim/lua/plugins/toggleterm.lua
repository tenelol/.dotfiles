local plugin = require("nix-plugin")

return {
  plugin.spec("toggleterm-nvim", {
  config = function()
    require("toggleterm").setup({
      size = 15,
      open_mapping = [[<C-\>]],
      shade_terminals = true,
      direction = "horizontal",
    })
  end
  })
}
