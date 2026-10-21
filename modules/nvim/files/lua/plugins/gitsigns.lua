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

      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { silent = true, desc = "Select hunk" })
    end,
  }),
}
