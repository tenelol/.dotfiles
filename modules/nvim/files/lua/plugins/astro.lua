local plugin = require("nix-plugin")

return {
  plugin.spec("vim-astro", {
    enabled = vim.env.NVIM_WEB_WORKFLOW == "1",
    ft = { "astro" },
  }),
}
