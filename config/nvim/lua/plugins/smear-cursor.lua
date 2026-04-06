local plugin = require("nix-plugin")

return {
  plugin.spec("smear-cursor-nvim", {
  event = "VeryLazy",
  config = function()
    require("smear_cursor").setup()
  end,
})
}
