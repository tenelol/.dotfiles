local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-ts-autotag", {
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvim-ts-autotag").setup()
        end,
    }),
}
