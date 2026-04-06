local plugin = require("nix-plugin")

return {
    plugin.spec("nvim-lspconfig", {
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            plugin.dep("nvim-navic"),
        },
        config = function()
            local function telescope_picker(name, opts)
                return function()
                    require("lazy").load({ plugins = { "telescope-nvim" } })
                    require("telescope.builtin")[name](opts or {})
                end
            end

            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            local navic = require("nvim-navic")
            local lsp_augroup = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })
            local web_lsp_enabled = vim.env.NVIM_WEB_WORKFLOW == "1"

            navic.setup({
                highlight = true,
                separator = " > ",
                depth_limit = 5,
            })

            local function supports_inlay_hints(client)
                return vim.lsp.inlay_hint ~= nil and client:supports_method("textDocument/inlayHint")
            end

            local on_attach = function(client, bufnr)
                if client:supports_method("textDocument/documentSymbol") then
                    navic.attach(client, bufnr)
                end

                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end

                map("n", "K", vim.lsp.buf.hover, "Hover")
                map("n", "gd", telescope_picker("lsp_definitions"), "Go to definition")
                map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
                map("n", "gi", telescope_picker("lsp_implementations"), "Go to implementation")
                map("n", "gK", vim.lsp.buf.signature_help, "Signature help")
                map("n", "gr", telescope_picker("lsp_references"), "Go to references")
                map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
                map("n", "<leader>ld", function()
                    vim.diagnostic.open_float(nil, {
                        border = "rounded",
                        focusable = false,
                        scope = "cursor",
                        source = "if_many",
                    })
                end, "Line diagnostics")
                map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
                map("n", "<leader>ls", telescope_picker("lsp_document_symbols"), "Document symbols")
                map("n", "<leader>lS", telescope_picker("lsp_dynamic_workspace_symbols"), "Workspace symbols")
                map("n", "<leader>lf", function()
                    require("lazy").load({ plugins = { "conform-nvim" } })
                    require("conform").format({
                        async = true,
                        lsp_format = "fallback",
                    })
                end, "Format buffer")
                map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
                map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")

                if client:supports_method("textDocument/documentHighlight") then
                    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                        group = lsp_augroup,
                        buffer = bufnr,
                        callback = vim.lsp.buf.document_highlight,
                    })

                    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
                        group = lsp_augroup,
                        buffer = bufnr,
                        callback = vim.lsp.buf.clear_references,
                    })
                end

                vim.api.nvim_create_autocmd("CursorHold", {
                    group = lsp_augroup,
                    buffer = bufnr,
                    callback = function()
                        if vim.api.nvim_get_mode().mode ~= "n" then
                            return
                        end

                        vim.diagnostic.open_float(nil, {
                            border = "rounded",
                            focusable = false,
                            scope = "cursor",
                            source = "if_many",
                        })
                    end,
                })

                if supports_inlay_hints(client) then
                    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
                    map("n", "<leader>lh", function()
                        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                        vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
                    end, "Toggle inlay hints")
                end
            end

            local servers = {
                "lua_ls",
                "pyright",
                "gopls",
                "nil_ls",
                "jsonls",
            }

            if web_lsp_enabled then
                vim.list_extend(servers, {
                    "eslint",
                    "html",
                    "cssls",
                    "tailwindcss",
                    "ts_ls",
                    "astro",
                })
            end

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
