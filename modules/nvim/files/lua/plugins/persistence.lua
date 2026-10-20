local plugin = require("nix-plugin")

return {
  plugin.spec("persistence-nvim", {
    lazy = false,
    config = function()
      require("persistence").setup({
        options = vim.opt.sessionoptions:get(),
      })
    end,
  }),
}
