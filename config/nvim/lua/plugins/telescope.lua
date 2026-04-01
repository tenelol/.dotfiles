local plugin = require("nix-plugin")

return {
    plugin.spec("telescope-nvim", {
        dependencies = { plugin.dep("plenary-nvim") },
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

            vim.keymap.set("n", "<C-p>", project_find_files, { desc = "Quick open" })
            vim.keymap.set("n", "<leader>ff", project_find_files, { desc = "Find files" })
            vim.keymap.set("n", "<leader>fF", project_git_files, { desc = "Find git files" })
            vim.keymap.set("n", "<leader>fg", function()
                builtin.live_grep(project_opts())
            end, { desc = "Search in files" })
            vim.keymap.set("n", "<leader>fc", function()
                builtin.grep_string(project_opts())
            end, { desc = "Search word under cursor" })
            vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
            vim.keymap.set("n", "<leader>f/", function()
                builtin.current_buffer_fuzzy_find(themes.get_dropdown({
                    previewer = false,
                    winblend = 10,
                }))
            end, { desc = "Search current buffer" })
            vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
            vim.keymap.set("n", "<leader>fR", builtin.resume, { desc = "Resume last picker" })
        end,
    }),
}
