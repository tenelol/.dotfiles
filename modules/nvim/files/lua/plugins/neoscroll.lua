local plugin = require("nix-plugin")

return {
  plugin.spec("neoscroll-nvim", {
    event = "VeryLazy",
    config = function()
      require("neoscroll").setup({
        easing = "sine",
        duration_multiplier = 0.8,
        post_hook = function()
          -- Refresh scopes and breadcrumbs after Neoscroll restores movement events.
          vim.schedule(function()
            vim.api.nvim_exec_autocmds("CursorMoved", {})
          end)
        end,
      })
    end,
  }),
}
