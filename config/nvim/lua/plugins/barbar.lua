local plugin = require("nix-plugin")

return {
  plugin.spec("barbar-nvim", {
  dependencies = {
    plugin.dep("gitsigns-nvim"),
    plugin.dep("nvim-web-devicons"),
  },
  init = function() vim.g.barbar_auto_setup = false end,
  opts = {
    animation = true,
    auto_hide = false,
    tabpages = true,
    clickable = true,
  },
  }),
}
