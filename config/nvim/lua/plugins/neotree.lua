local plugin = require("nix-plugin")

return {
  plugin.spec("neo-tree-nvim", {
  dependencies = {
    plugin.dep("plenary-nvim"),
    plugin.dep("nvim-web-devicons"),
    plugin.dep("nui-nvim"),
  },
  config = function()
    vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left<CR>", { desc = "Toggle file tree" })
  end,
  }),
}
