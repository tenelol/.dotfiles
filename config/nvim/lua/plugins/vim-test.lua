return {
  {
    "vim-test/vim-test",
    config = function()
      vim.g["test#python#runner"] = "pytest"

      vim.keymap.set("n", "<leader>tn", ":TestNearest<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tf", ":TestFile<CR>", { silent = true })
      vim.keymap.set("n", "<leader>ts", ":TestSuite<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tl", ":TestLast<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tv", ":TestVisit<CR>", { silent = true })
    end,
  },
}
