local plugin = require("nix-plugin")

return {
  plugin.spec("comment-nvim", {
  event = "VeryLazy",
  config = function()
    require("Comment").setup()
  end,
  }),
}
