local plugin = require("nix-plugin")

return {
    plugin.spec("markdown-preview-nvim", {
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    config = function()
        vim.g.mkdp_auto_start = 0
        vim.g.mkdp_refresh_slow = 0
	--vim.g.mkdp_browser = "vivaldi"
    end,
    lazy = true
})
}
