local plugin = require("nix-plugin")

return {
  plugin.spec("markdown-preview-nvim", {
    enabled = vim.env.NVIM_WEB_WORKFLOW == "1",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    config = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_command_for_global = 0
      vim.g.mkdp_browser = "Zen Browser"
    end,
    lazy = true,
  }),
}
