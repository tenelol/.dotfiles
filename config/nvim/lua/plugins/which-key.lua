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
                { "<leader>b", group = "buffer" },
                { "<leader>ey", desc = "Yazi (current file)" },
                { "<leader>eY", desc = "Yazi (cwd)" },
                { "<leader>c", group = "color" },
                { "<leader>e", group = "explorer" },
                { "<leader>f", group = "find" },
                { "<leader>d", group = "debug" },
                { "<leader>h", group = "git hunk" },
                { "<leader>l", group = "language" },
                { "<leader>o", group = "open" },
                { "<leader>p", group = "platformio" },
                { "<leader>s", group = "session" },
                { "<leader>x", group = "problems" },
                { "<leader>t", group = "test" },
                { "<leader>pb", desc = "Build PlatformIO project" },
                { "<leader>pc", desc = "Generate compile database" },
                { "<leader>pi", desc = "Initialize PlatformIO project" },
                { "<leader>pm", desc = "Open PlatformIO monitor" },
                { "<leader>pu", desc = "Upload PlatformIO project" },
                { "<leader>oa", desc = "Toggle all terminals" },
                { "<leader>ot", desc = "New terminal" },
                { "<leader>oT", desc = "Select terminal" },
                { "<leader>f/", desc = "Search current buffer" },
                { "<leader>fF", desc = "Find git files" },
                { "<leader>fR", desc = "Resume last picker" },
                { "<leader>fc", desc = "Search word under cursor" },
                { "<leader>eb", desc = "Explorer buffers" },
                { "<leader>ef", desc = "Explorer filesystem" },
                { "<leader>eg", desc = "Explorer git status" },
                { "<leader>ld", desc = "Line diagnostics" },
                { "<leader>lh", desc = "Toggle inlay hints" },
                { "<leader>to", desc = "Toggle test output" },
                { "<leader>xx", desc = "Workspace diagnostics" },
                { "<leader>xs", desc = "Document symbols problems" },
            })
        end,
    }),
}
