local plugin = require("nix-plugin")

return {
  plugin.spec("barbar-nvim", {
    dependencies = {
      plugin.dep("nvim-web-devicons"),
    },
    init = function() vim.g.barbar_auto_setup = false end,
    config = function()
      require("barbar").setup({
        animation = true,
        auto_hide = false,
        tabpages = true,
        clickable = true,
      })
    end,
  }),
}
