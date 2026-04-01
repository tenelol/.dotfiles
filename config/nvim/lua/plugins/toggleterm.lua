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

    map("n", "<leader>to", function()
      require("core.test-terminal").toggle()
    end, { silent = true, desc = "Toggle test output" })
  end
  })
}
