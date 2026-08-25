local plugin = require("nix-plugin")

return {
  plugin.spec("vim-test", {
    cmd = {
      "TestNearest",
      "TestFile",
      "TestSuite",
      "TestLast",
      "TestVisit",
    },
    keys = {
      { "<leader>tn", desc = "Run nearest test" },
      { "<leader>tf", desc = "Run file tests" },
      { "<leader>ts", desc = "Run test suite" },
      { "<leader>tl", desc = "Run last test" },
      { "<leader>tv", desc = "Visit last test" },
    },
    config = function()
      _G.toggleterm_test_strategy = function(cmd)
        require("core.test-terminal").run(cmd)
      end

      vim.cmd([[
        function! ToggleTermTestStrategy(cmd) abort
          call v:lua.toggleterm_test_strategy(a:cmd)
        endfunction
      ]])

      vim.g["test#python#runner"] = "pytest"
      vim.g["test#strategy"] = "toggleterm"
      vim.g["test#preserve_screen"] = 1
      vim.g["test#custom_strategies"] = {
        toggleterm = vim.fn["function"]("ToggleTermTestStrategy"),
      }

      vim.keymap.set("n", "<leader>tn", ":TestNearest<CR>", { silent = true, desc = "Run nearest test" })
      vim.keymap.set("n", "<leader>tf", ":TestFile<CR>", { silent = true, desc = "Run file tests" })
      vim.keymap.set("n", "<leader>ts", ":TestSuite<CR>", { silent = true, desc = "Run test suite" })
      vim.keymap.set("n", "<leader>tl", ":TestLast<CR>", { silent = true, desc = "Run last test" })
      vim.keymap.set("n", "<leader>tv", ":TestVisit<CR>", { silent = true, desc = "Visit last test" })
    end,
  }),
}
