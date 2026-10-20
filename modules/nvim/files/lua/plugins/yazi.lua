local plugin = require("nix-plugin")

return {
  plugin.spec("yazi-nvim", {
    cmd = "Yazi",
    config = function()
      require("yazi").setup({
        open_for_directories = false,
        keymaps = {
          show_help = "<F1>",
        },
      })
    end,
  }),
}
