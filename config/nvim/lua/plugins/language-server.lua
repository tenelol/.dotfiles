local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-lspconfig", {
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            plugin.dep("nvim-navic"),
            plugin.dep("telescope-nvim"),
        },
        config = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            local navic = require("nvim-navic")
            local builtin = require("telescope.builtin")

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
                map("n", "gd", builtin.lsp_definitions, "Go to definition")
                map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
                map("n", "gi", builtin.lsp_implementations, "Go to implementation")
                map("n", "gr", builtin.lsp_references, "Go to references")
                map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
                map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>ls", builtin.lsp_document_symbols, "Document symbols")
                map("n", "<leader>lS", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
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
                "eslint",
                "html",
                "cssls",
                "tailwindcss",
                "ts_ls",
                "jsonls",
                "astro",
            }

            vim.lsp.config("ts_ls", {
                capabilities = capabilities,
                on_attach = on_attach,
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints = "all",
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = "all",
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayVariableTypeHintsWhenTypeMatchesName = false,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                },
            })

            vim.lsp.config("eslint", {
                capabilities = capabilities,
                on_attach = on_attach,
                settings = {
                    format = false,
                    workingDirectory = {
                        mode = "auto",
                    },
                },
            })

            for _, server in ipairs(servers) do
                if server ~= "ts_ls" and server ~= "eslint" then
                    vim.lsp.config(server, {
                        capabilities = capabilities,
                        on_attach = on_attach,
                    })
                end
            end

            vim.lsp.enable(servers)
        end,
    }),
}
