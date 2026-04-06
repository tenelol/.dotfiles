local plugin = require("nix-plugin")

return {
  plugin.spec("barbar-nvim", {
    dependencies = {
      plugin.dep("nvim-web-devicons"),
    },
    init = function() vim.g.barbar_auto_setup = false end,
    config = function()
      local map = vim.keymap.set

      require("barbar").setup({
        animation = true,
        auto_hide = false,
        tabpages = true,
        clickable = true,
        focus_on_close = "left",
      })

      map("n", "[b", "<Cmd>BufferPrevious<CR>", { silent = true, desc = "Previous buffer" })
      map("n", "]b", "<Cmd>BufferNext<CR>", { silent = true, desc = "Next buffer" })
      map("n", "<leader>bb", "<Cmd>BufferPick<CR>", { silent = true, desc = "Pick buffer" })
      map("n", "<leader>bc", "<Cmd>BufferClose<CR>", { silent = true, desc = "Close buffer" })
      map("n", "<leader>bo", "<Cmd>BufferCloseAllButCurrent<CR>", { silent = true, desc = "Close other buffers" })
      map("n", "<leader>bp", "<Cmd>BufferPin<CR>", { silent = true, desc = "Toggle pin" })
      map("n", "<leader>bH", "<Cmd>BufferMovePrevious<CR>", { silent = true, desc = "Move buffer left" })
      map("n", "<leader>bL", "<Cmd>BufferMoveNext<CR>", { silent = true, desc = "Move buffer right" })

      for i = 1, 9 do
        map("n", "<A-" .. i .. ">", "<Cmd>BufferGoto " .. i .. "<CR>", { silent = true, desc = "Go to buffer " .. i })
      end
      map("n", "<A-0>", "<Cmd>BufferLast<CR>", { silent = true, desc = "Go to last buffer" })
    end,
  }),
}
