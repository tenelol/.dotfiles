local plugin = require("nix-plugin")

return {
  plugin.spec("gitsigns-nvim", {
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local gitsigns = require("gitsigns")
      local map = vim.keymap.set

      gitsigns.setup({
        current_line_blame = false,
        current_line_blame_opts = {
          delay = 250,
        },
      })

      map("n", "]h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]h", bang = true })
        else
          gitsigns.nav_hunk("next")
        end
      end, { silent = true, desc = "Next hunk" })

      map("n", "[h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[h", bang = true })
        else
          gitsigns.nav_hunk("prev")
        end
      end, { silent = true, desc = "Previous hunk" })

      map("n", "<leader>hs", gitsigns.stage_hunk, { silent = true, desc = "Stage hunk" })
      map("n", "<leader>hr", gitsigns.reset_hunk, { silent = true, desc = "Reset hunk" })
      map("n", "<leader>hS", gitsigns.stage_buffer, { silent = true, desc = "Stage buffer" })
      map("n", "<leader>hu", gitsigns.undo_stage_hunk, { silent = true, desc = "Undo stage hunk" })
      map("n", "<leader>hR", gitsigns.reset_buffer, { silent = true, desc = "Reset buffer" })
      map("n", "<leader>hb", gitsigns.blame_line, { silent = true, desc = "Blame line" })
      map("n", "<leader>hB", gitsigns.toggle_current_line_blame, { silent = true, desc = "Toggle line blame" })
      map("n", "<leader>hp", gitsigns.preview_hunk, { silent = true, desc = "Preview hunk" })
      map("n", "<leader>hd", gitsigns.diffthis, { silent = true, desc = "Diff this" })
      map("n", "<leader>hD", function()
        gitsigns.diffthis("~")
      end, { silent = true, desc = "Diff against previous revision" })
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { silent = true, desc = "Select hunk" })
    end,
  }),
}
