local plugin = require("nix-plugin")

return {
  plugin.spec("toggleterm-nvim", {
    cmd = { "ToggleTerm", "TermExec", "TermNew", "TermSelect", "ToggleTermToggleAll" },
    keys = {
      { "<C-\\>", desc = "Toggle terminal" },
      { "<C-t>", desc = "Toggle floating terminal" },
      { "<leader>ot", desc = "New terminal" },
      { "<leader>oT", desc = "Select terminal" },
      { "<leader>oa", desc = "Toggle all terminals" },
      { "[T", desc = "Previous terminal" },
      { "]T", desc = "Next terminal" },
      { "<leader>to", desc = "Toggle test output" },
    },
    config = function()
      local terminal = require("core.terminal")
      local map = vim.keymap.set

      require("toggleterm").setup({
        size = 10,
        open_mapping = [[<C-\>]],
        shade_terminals = true,
        direction = "horizontal",
        persist_mode = true,
        start_in_insert = true,
      })

      map("n", "<C-t>", function()
        terminal.toggle_float()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("t", "<C-t>", function()
        terminal.toggle_float()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("n", "<leader>ot", function()
        terminal.new()
      end, { silent = true, desc = "New terminal" })

      map("n", "<leader>oT", function()
        terminal.select()
      end, { silent = true, desc = "Select terminal" })

      map("n", "<leader>oa", function()
        terminal.toggle_all()
      end, { silent = true, desc = "Toggle all terminals" })

      map({ "n", "t" }, "]T", function()
        terminal.next()
      end, { silent = true, desc = "Next terminal" })

      map({ "n", "t" }, "[T", function()
        terminal.previous()
      end, { silent = true, desc = "Previous terminal" })

      map("n", "<leader>to", function()
        require("core.test-terminal").toggle()
      end, { silent = true, desc = "Toggle test output" })
    end,
  }),
}
