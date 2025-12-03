return {
  "smoka7/hop.nvim",
  version = "*",
  config = function()
    local hop = require("hop")
    hop.setup({
      keys = "etovxqpdygfblzhckisuran",
    })

    -- leader leader w で単語ジャンプ
    vim.api.nvim_set_keymap(
      "n",
      "<leader><leader>w",
      "<cmd>HopWord<CR>",
      { noremap = true, silent = true, desc = "Hop to word" }
    )
  end
}

