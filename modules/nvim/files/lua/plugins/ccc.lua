local plugin = require("nix-plugin")

return {
    plugin.spec("ccc-nvim", {
        cmd = {
            "CccPick",
            "CccConvert",
            "CccHighlighterToggle",
        },
        config = function()
            require("ccc").setup({})
        end,
    }),
}
