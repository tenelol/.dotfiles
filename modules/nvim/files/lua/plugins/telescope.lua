local plugin = require("nix-plugin")

return {
    plugin.spec("telescope-nvim", {
        dependencies = { plugin.dep("plenary-nvim") },
        cmd = "Telescope",
        keys = {
            { "<C-p>", desc = "Quick open" },
            { "<leader>ff", desc = "Find files" },
            { "<leader>fF", desc = "Find git files" },
            { "<leader>fg", desc = "Search in files" },
            { "<leader>fc", desc = "Search word under cursor" },
            { "<leader>fb", desc = "Find buffers" },
            { "<leader>f/", desc = "Search current buffer" },
            { "<leader>fr", desc = "Recent files" },
            { "<leader>fR", desc = "Resume last picker" },
        },
        config = function()
            local project = require("core.project")
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")
            local themes = require("telescope.themes")

            local function project_opts(opts)
                return vim.tbl_extend("force", {
                    cwd = project.buffer_root(0),
                }, opts or {})
            end

            local function project_find_files()
                builtin.find_files(project_opts())
            end

            local function project_git_files()
                local ok = pcall(builtin.git_files, project_opts({
                    show_untracked = true,
                }))

                if not ok then
                    project_find_files()
                end
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
            map("n", "<leader>ff", project_find_files, { desc = "Find files" })
            map("n", "<leader>fF", project_git_files, { desc = "Find git files" })
            map("n", "<leader>fg", function()
                builtin.live_grep(project_opts())
            end, { desc = "Search in files" })
            map("n", "<leader>fc", function()
                builtin.grep_string(project_opts())
            end, { desc = "Search word under cursor" })
            map("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
            map("n", "<leader>f/", function()
                builtin.current_buffer_fuzzy_find(themes.get_dropdown({
                    previewer = false,
                    winblend = 10,
                }))
            end, { desc = "Search current buffer" })
            map("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
            map("n", "<leader>fR", builtin.resume, { desc = "Resume last picker" })
        end,
    }),
}
