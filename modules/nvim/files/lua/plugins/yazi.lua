local plugin = require("nix-plugin")

return {
  plugin.spec("yazi-nvim", {
    keys = {
      { "<leader>ey", "<cmd>Yazi<cr>",        desc = "Yazi (current file)" },
      { "<leader>eY", "<cmd>Yazi cwd<cr>",    desc = "Yazi (cwd)" },
    },
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
