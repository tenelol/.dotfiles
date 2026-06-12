local plugin = require("nix-plugin")

return {
    plugin.spec("copilot-vim", {
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            vim.g.copilot_no_tab_map = true
            local accept_key = vim.fn.has("wsl") == 1 and "<M-l>" or "<C-l>"

            vim.keymap.set("i", accept_key, function()
                return vim.fn["copilot#Accept"]("<CR>")
            end, {
                silent = true,
                expr = true,
                replace_keycodes = false,
                desc = "Accept Copilot suggestion",
            })
        end,
    }),
}
