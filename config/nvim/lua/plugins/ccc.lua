local plugin = require("nix-plugin")

return {
    plugin.spec("ccc-nvim", {
        cmd = {
            "CccPick",
            "CccConvert",
            "CccHighlighterToggle",
        },
        keys = {
            {
                "<leader>cp",
                "<Cmd>CccPick<CR>",
                desc = "Open color picker",
            },
            {
                "<leader>cc",
                "<Cmd>CccConvert<CR>",
                desc = "Convert color format",
            },
            {
                "<leader>ct",
                "<Cmd>CccHighlighterToggle<CR>",
                desc = "Toggle color picker highlighter",
            },
        },
        config = function()
            require("ccc").setup({})
        end,
    }),
}
