local plugin = require("nix-plugin")

return {
    plugin.spec("trouble-nvim", {
        cmd = "Trouble",
        dependencies = {
            plugin.dep("nvim-web-devicons"),
        },
        config = function()
            require("trouble").setup({})

            vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>",
                { silent = true, desc = "Toggle problems" })
            vim.keymap.set("n", "<leader>xw", "<cmd>Trouble diagnostics toggle<CR>",
                { silent = true, desc = "Workspace diagnostics" })
            vim.keymap.set("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>",
                { silent = true, desc = "Document diagnostics" })
            vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { silent = true, desc = "Quickfix list" })
            vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<CR>",
                { silent = true, desc = "Location list" })
        end,
    }),
}
