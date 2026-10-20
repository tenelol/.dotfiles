local plugin = require("nix-plugin")

return {
    plugin.spec("which-key-nvim", {
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")

            wk.setup({
                delay = 200,
            })

            wk.add({
                { "<leader>i", group = "ai" },
                { "<leader>iC", desc = "Open Claude Code" },
                { "<leader>ix", desc = "Open Codex CLI" },
                { "<leader>b", group = "buffer" },
                { "<leader>f", group = "find" },
                { "<leader>g", group = "git" },
                { "<leader>h", group = "git hunk" },
                { "<leader>l", group = "language" },
                { "<leader>n", group = "org" },
                { "<leader>o", group = "open" },
                { "<leader>r", group = "replace" },
                { "<leader>x", group = "problems" },
                { "<leader>t", group = "test" },
                { "<leader>oa", desc = "Toggle all terminals" },
                { "<leader>on", desc = "Next terminal" },
                { "<leader>op", desc = "Previous terminal" },
                { "<leader>ot", desc = "New terminal" },
                { "<leader>oT", desc = "Select terminal" },
                { "<leader>f/", desc = "Search current buffer" },
                { "<leader>fF", desc = "Find git files" },
                { "<leader>fR", desc = "Resume last picker" },
                { "<leader>fc", desc = "Search word under cursor" },
                { "<leader>gd", desc = "Open diff view" },
                { "<leader>gf", desc = "LazyGit (current file)" },
                { "<leader>gg", desc = "LazyGit" },
                { "<leader>gH", desc = "Repository history" },
                { "<leader>gh", desc = "File history" },
                { "<leader>gq", desc = "Close diff view" },
                { "<leader>gs", desc = "Git status" },
                { "<leader>gt", desc = "Git tree" },
                { "<leader>va", desc = "Select all" },
                { "<leader>ld", desc = "Line diagnostics" },
                { "<leader>lh", desc = "Toggle inlay hints" },
                { "<leader>to", desc = "Toggle test output" },
                { "<leader>xx", desc = "Workspace diagnostics" },
                { "<leader>xs", desc = "Document symbols problems" },
            })
        end,
    }),
}
