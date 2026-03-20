local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-treesitter", {
    config = function()
        local configs = require("nvim-treesitter.configs")
        configs.setup({
            auto_install = false,
            highlight = { enable = true},
            indent = { enable = true }
        })
    end
})
}
