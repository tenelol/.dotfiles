local plugin = require("nix-plugin")

return {
  plugin.spec("copilot-vim", {
  lazy = false,  -- ← ここ
  config = function()
    vim.g.copilot_no_tab_map = true
    vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', {
      silent = true,
      expr = true,
    })
  end,
  }),
}
