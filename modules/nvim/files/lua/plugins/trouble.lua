local plugin = require("nix-plugin")

return {
    plugin.spec("trouble-nvim", {
        cmd = "Trouble",
        dependencies = {
            plugin.dep("nvim-web-devicons"),
        },
        config = function()
            require("trouble").setup({
                focus = true,
                warn_no_results = false,
            })
        end,
    }),
}
