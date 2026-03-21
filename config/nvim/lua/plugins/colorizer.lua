local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-colorizer-lua", {
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("colorizer").setup({
                css = { mode = "background" },
                scss = { mode = "background" },
                sass = { mode = "background" },
                html = { mode = "background" },
                javascript = { mode = "background" },
                javascriptreact = { mode = "background" },
                typescriptreact = { mode = "background" },
                astro = { mode = "background" },
            }, {
                names = false,
                rgb_fn = true,
                hsl_fn = true,
                css = true,
                css_fn = true,
                tailwind = true,
            })
        end,
    }),
}
