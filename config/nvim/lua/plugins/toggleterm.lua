local plugin = require("nix-plugin")

return {
  plugin.spec("toggleterm-nvim", {
    config = function()
      local map = vim.keymap.set

      require("toggleterm").setup({
        size = 10,
        open_mapping = [[<C-\>]],
        shade_terminals = true,
        direction = "horizontal",
        persist_mode = true,
        start_in_insert = true,
      })

      local Terminal = require("toggleterm.terminal").Terminal

      local float_term = Terminal:new({
        direction = "float",
        float_opts = { border = "rounded" },
        hidden = true,
      })

      map("n", "<C-t>", function()
        float_term:toggle()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("t", "<C-t>", function()
        float_term:toggle()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("n", "<leader>to", function()
        require("core.test-terminal").toggle()
      end, { silent = true, desc = "Toggle test output" })
    end,
  }),
}
