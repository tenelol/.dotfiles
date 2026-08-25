local plugin = require("nix-plugin")

return {
    plugin.spec("todo-comments-nvim", {
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            plugin.dep("plenary-nvim"),
        },
        config = function()
            require("todo-comments").setup({})

            vim.keymap.set("n", "]t", function()
                require("todo-comments").jump_next()
            end, { silent = true, desc = "Next todo comment" })

            vim.keymap.set("n", "[t", function()
                require("todo-comments").jump_prev()
            end, { silent = true, desc = "Previous todo comment" })

            vim.keymap.set("n", "<leader>xt", "<cmd>TodoTrouble<CR>", { silent = true, desc = "Todo comments" })
            vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { silent = true, desc = "Find todo comments" })
        end,
    }),
}
