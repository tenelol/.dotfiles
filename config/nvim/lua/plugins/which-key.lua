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
                { "<leader>c", group = "color" },
                { "<leader>f", group = "find" },
                { "<leader>d", group = "debug" },
                { "<leader>h", group = "git hunk" },
                { "<leader>l", group = "language" },
                { "<leader>o", group = "open" },
                { "<leader>s", group = "session" },
                { "<leader>x", group = "problems" },
                { "<leader>t", group = "test" },
            })
        end,
    }),
}
