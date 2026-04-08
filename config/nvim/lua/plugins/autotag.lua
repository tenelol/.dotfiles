local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-ts-autotag", {
        enabled = vim.env.NVIM_WEB_WORKFLOW == "1",
        ft = {
            "html",
            "xml",
            "javascriptreact",
            "typescriptreact",
            "astro",
        },
        config = function()
            require("nvim-ts-autotag").setup({
                opts = {
                    enable_close = true,
                    -- Work around a nil parser bug in the current plugin build.
                    enable_rename = false,
                    enable_close_on_slash = false,
                },
            })
        end,
    }),
}
