local plugin = require("nix-plugin")

return {
  plugin.spec("nvim-surround", {
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end,
  }),
}
