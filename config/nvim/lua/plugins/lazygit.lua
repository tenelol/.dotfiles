local plugin = require("nix-plugin")

return {
  plugin.spec("lazygit-nvim", {
    dependencies = {
      plugin.dep("plenary-nvim"),
    },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
      { "<leader>gf", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit (current file)" },
    },
  }),
}
