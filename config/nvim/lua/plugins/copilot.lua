local plugin = require("nix-plugin")
local copilot_enabled = vim.env.NVIM_COPILOT == "1"

vim.g.copilot_enabled = copilot_enabled and 1 or 0
vim.g.copilot_no_tab_map = true

return {
    plugin.spec("copilot-vim", {
        enabled = copilot_enabled,
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
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
