local plugin = require("nix-plugin")

return {
    plugin.spec("persistence-nvim", {
        event = "BufReadPre",
        config = function()
            require("persistence").setup({
                options = vim.opt.sessionoptions:get(),
            })

            vim.keymap.set("n", "<leader>ss", function()
                require("persistence").load()
            end, { silent = true, desc = "Restore session" })

            vim.keymap.set("n", "<leader>sl", function()
                require("persistence").load({ last = true })
            end, { silent = true, desc = "Restore last session" })

            vim.keymap.set("n", "<leader>sd", function()
                require("persistence").stop()
            end, { silent = true, desc = "Disable session save" })
        end,
    }),
}
