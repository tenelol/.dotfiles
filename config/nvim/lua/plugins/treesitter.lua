local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-treesitter", {
        config = function()
            require("nvim-treesitter").setup({
                auto_install = false,
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    }),
}
