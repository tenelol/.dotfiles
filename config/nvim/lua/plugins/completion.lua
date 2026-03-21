local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-cmp", {
        event = { "InsertEnter", "CmdlineEnter" },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<CR>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.confirm({ select = true })
                            return
                        end

                        local ok, expandable = pcall(vim.fn["emmet#isExpandable"])
                        if ok and expandable == 1 then
                            local keys = vim.fn["emmet#expandAbbrIntelligent"]("\r")
                            vim.api.nvim_feedkeys(vim.keycode(keys), "m", false)
                            return
                        end

                        fallback()
                    end, { "i", "s" }),
                    ["<C-j>"] = cmp.mapping(function(fallback)
                        if luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<C-k>"] = cmp.mapping(function(fallback)
                        if luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                }, {
                    { name = "buffer" },
                    { name = "path" },
                }),
            })

            cmp.setup.cmdline({ "/", "?" }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = "buffer" },
                },
            })

            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = "cmdline" },
                },
            })
        end,
    }),
    plugin.dep("cmp-nvim-lsp"),
    plugin.dep("cmp-buffer"),
    plugin.dep("cmp-path"),
    plugin.dep("cmp-cmdline"),
    plugin.dep("cmp_luasnip"),
    plugin.dep("luasnip"),
    plugin.dep("friendly-snippets"),
}
