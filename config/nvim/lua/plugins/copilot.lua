local plugin = require("nix-plugin")

return {
  plugin.spec("copilot-vim", {
  lazy = false,  -- ← ここ
  config = function()
    vim.g.copilot_no_tab_map = true

    vim.keymap.set("i", "<C-l>", function()
      return vim.fn["copilot#Accept"]("<CR>")
    end, {
      silent = true,
      expr = true,
      replace_keycodes = false,
      desc = "Accept Copilot suggestion",
    })
  end,
  }),
}
