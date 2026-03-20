local plugin = require("nix-plugin")

return {
  plugin.spec("vim-test", {
    config = function()
      vim.g["test#python#runner"] = "pytest"

      vim.keymap.set("n", "<leader>tn", ":TestNearest<CR>", { silent = true, desc = "Run nearest test" })
      vim.keymap.set("n", "<leader>tf", ":TestFile<CR>", { silent = true, desc = "Run file tests" })
      vim.keymap.set("n", "<leader>ts", ":TestSuite<CR>", { silent = true, desc = "Run test suite" })
      vim.keymap.set("n", "<leader>tl", ":TestLast<CR>", { silent = true, desc = "Run last test" })
      vim.keymap.set("n", "<leader>tv", ":TestVisit<CR>", { silent = true, desc = "Visit last test" })
    end,
  }),
}
