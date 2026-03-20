local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-lspconfig", {
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            plugin.dep("nvim-navic"),
        },
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            local navic = require("nvim-navic")

            navic.setup({
                highlight = true,
                separator = " > ",
                depth_limit = 5,
            })

            local on_attach = function(client, bufnr)
                if client:supports_method("textDocument/documentSymbol") then
                    navic.attach(client, bufnr)
                end

                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end

                map("n", "K", vim.lsp.buf.hover, "Hover")
                map("n", "gd", vim.lsp.buf.definition, "Go to definition")
                map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
                map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
                map("n", "gr", vim.lsp.buf.references, "Go to references")
                map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
                map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>lf", function()
                    vim.lsp.buf.format({ async = true })
                end, "Format buffer")
                map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
                map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
            end

            local servers = {
                "lua_ls",
                "pyright",
                "gopls",
                "nil_ls",
                "html",
                "cssls",
                "tailwindcss",
                "ts_ls",
                "jsonls",
                "marksman",
                "astro",
            }

            for _, server in ipairs(servers) do
                vim.lsp.config(server, {
                    capabilities = capabilities,
                    on_attach = on_attach,
                })
            end

            vim.lsp.enable(servers)
        end,
    }),
}
