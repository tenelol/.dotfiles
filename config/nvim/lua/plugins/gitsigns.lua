local plugin = require("nix-plugin")

return {
  plugin.spec("gitsigns-nvim", {
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        current_line_blame = true,
      })

      vim.keymap.set("n", "]h", "<cmd>Gitsigns next_hunk<CR>", { silent = true, desc = "Next hunk" })
      vim.keymap.set("n", "[h", "<cmd>Gitsigns prev_hunk<CR>", { silent = true, desc = "Previous hunk" })
      vim.keymap.set("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", { silent = true, desc = "Stage hunk" })
      vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", { silent = true, desc = "Reset hunk" })
      vim.keymap.set("n", "<leader>hb", "<cmd>Gitsigns blame_line<CR>", { silent = true, desc = "Blame line" })
      vim.keymap.set("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>", { silent = true, desc = "Preview hunk" })
    end,
  }),
}
