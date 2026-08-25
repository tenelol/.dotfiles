local plugin = require("nix-plugin")

return {
    plugin.spec("emmet-vim", {
        enabled = vim.env.NVIM_WEB_WORKFLOW == "1",
        ft = {
            "html",
            "css",
            "sass",
            "scss",
            "javascriptreact",
            "typescriptreact",
            "astro",
        },
        init = function()
            vim.g.user_emmet_install_global = 0
            vim.g.user_emmet_settings = {
                sass = {
                    extends = "css",
                },
                scss = {
                    extends = "css",
                },
                javascriptreact = {
                    extends = "html",
                },
                typescriptreact = {
                    extends = "html",
                },
                astro = {
                    extends = "html",
                },
            }
        end,
        config = function()
            local emmet_group = vim.api.nvim_create_augroup("EmmetInstall", { clear = true })
            local emmet_filetypes = {
                "html",
                "css",
                "sass",
                "scss",
                "javascriptreact",
                "typescriptreact",
                "astro",
            }

            local function set_emmet_tab_mapping(bufnr)
                vim.keymap.set("i", "<Tab>", function()
                    local ok, expandable = pcall(vim.fn["emmet#isExpandable"])
                    if ok and expandable == 1 then
                        vim.fn["emmet#expandAbbr"](0, "")
                        return
                    end

                    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "n", false)
                end, {
                    buffer = bufnr,
                    noremap = true,
                    silent = true,
                    desc = "Expand Emmet abbreviation",
                })
            end

            vim.cmd("EmmetInstall")
            set_emmet_tab_mapping(0)
            vim.api.nvim_create_autocmd("FileType", {
                group = emmet_group,
                pattern = emmet_filetypes,
                callback = function(args)
                    vim.cmd("EmmetInstall")
                    set_emmet_tab_mapping(args.buf)
                end,
            })
        end,
    }),
}
