local plugin = require("nix-plugin")

return {
    plugin.spec("telescope-nvim", {
        dependencies = { plugin.dep("plenary-nvim"), plugin.dep("snacks-nvim") },
        cmd = "Telescope",
        keys = {
            { "<C-p>", desc = "Quick open" },
            { "<leader>m", desc = "Search memos" },
            { "<leader>M", desc = "Find memo files" },
        },
        config = function()
            local project = require("core.project")
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")
            local animation = require("core.telescope-animation")

            local function project_opts(opts)
                return vim.tbl_extend("force", {
                    cwd = project.buffer_root(0),
                    attach_mappings = animation.attach,
                }, opts or {})
            end

            local function project_find_files()
                builtin.find_files(project_opts())
            end

            telescope.setup({
                defaults = {
                    prompt_prefix = "  ",
                    selection_caret = "  ",
                    sorting_strategy = "ascending",
                    layout_config = {
                        horizontal = {
                            prompt_position = "top",
                            preview_width = 0.55,
                        },
                        width = 0.92,
                        height = 0.88,
                    },
                    file_ignore_patterns = {
                        ".git/",
                        "node_modules/",
                        "dist/",
                        "build/",
                    },
                },
            })

            local map = vim.keymap.set

            map("n", "<C-p>", project_find_files, { desc = "Quick open" })
            -- Org notes live in ~/org whatever project is open.
            map("n", "<leader>m", function()
                builtin.live_grep(project_opts({ cwd = "~/org", glob_pattern = "*.org" }))
            end, { desc = "Search memos" })
            map("n", "<leader>M", function()
                builtin.find_files(project_opts({ cwd = "~/org", follow = true }))
            end, { desc = "Find memo files" })
        end,
    }),
}
