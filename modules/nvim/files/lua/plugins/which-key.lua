local plugin = require("nix-plugin")

return {
    plugin.spec("which-key-nvim", {
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")

            -- Labels come from each mapping's desc; there are no groups left to name.
            wk.setup({
                delay = 200,
            })
        end,
    }),
}
