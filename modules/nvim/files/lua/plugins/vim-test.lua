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

    end,
  }),
}
