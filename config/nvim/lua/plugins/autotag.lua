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
            require("nvim-ts-autotag").setup()
        end,
    }),
}
