local plugin = require("nix-plugin")

return {
    plugin.spec("aerial-nvim", {
        dependencies = {
            plugin.dep("nvim-treesitter"),
            plugin.dep("nvim-web-devicons"),
        },
        config = function()
            require("aerial").setup({
                attach_mode = "global",
                backends = { "lsp", "treesitter", "markdown" },
                layout = {
                    min_width = 28,
                    default_direction = "right",
                },
                show_guides = true,
            })

            vim.keymap.set("n", "<leader>lo", "<cmd>AerialToggle right<CR>", { silent = true, desc = "Toggle outline" })
            vim.keymap.set("n", "[s", "<cmd>AerialPrev<CR>", { silent = true, desc = "Previous symbol" })
            vim.keymap.set("n", "]s", "<cmd>AerialNext<CR>", { silent = true, desc = "Next symbol" })
        end,
    }),
}
