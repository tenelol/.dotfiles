local plugin = require("nix-plugin")

return {
  plugin.spec("which-key-nvim", {
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")

      wk.setup({
        delay = 200,
      })

      wk.add({
        { "<leader>d", group = "debug" },
        { "<leader>t", group = "test" },
      })
    end,
  }),
}
