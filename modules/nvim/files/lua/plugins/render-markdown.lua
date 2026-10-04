local plugin = require("nix-plugin")

return {
  plugin.spec("render-markdown-nvim", {
    dependencies = { plugin.dep("nvim-treesitter"), plugin.dep("nvim-web-devicons") },
    ft = { "markdown" },
    config = function()
      require("render-markdown").setup({})
    end,
  }),
}
