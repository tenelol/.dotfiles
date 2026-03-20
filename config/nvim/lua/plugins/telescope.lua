local plugin = require("nix-plugin")

return {
  plugin.spec("telescope-nvim", {
  dependencies = { plugin.dep("plenary-nvim") },
  config = function()
    local builtin = require("telescope.builtin")
    vim.keymap.set("n", "<C-b>", builtin.find_files, { desc = "Find files" })
  end,
  }),
}
