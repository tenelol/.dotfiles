local plugin = require("nix-plugin")

return {
  plugin.spec("winresizer", {
  event = "VeryLazy",
  config = function()
    vim.keymap.set("n", "<C-w>e", ":WinResizerStartResize<CR>", { silent = true, desc = "Resize window" })
  end,
  }),
}
