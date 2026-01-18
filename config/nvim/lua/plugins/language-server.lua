return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = {
        "lua_ls",
        "pyright",
        "gopls",
        "nil_ls",
        "html",
        "cssls",
        "tailwindcss",
        "tsserver",
        "jsonls",
        "marksman",
        "astro",
      }

      for _, server in ipairs(servers) do
        vim.lsp.config(server, {
          capabilities = capabilities,
        })
      end

      vim.lsp.enable(servers)

      local format_group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true })
      local function get_clients(bufnr)
        if vim.lsp.get_clients then
          return vim.lsp.get_clients({ bufnr = bufnr })
        end
        return vim.lsp.get_active_clients({ bufnr = bufnr })
      end

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = format_group,
        callback = function(args)
          local clients = get_clients(args.buf)
          if #clients == 0 then
            if vim.bo[args.buf].filetype == "javascriptreact" then
              local view = vim.fn.winsaveview()
              vim.cmd("silent! normal! gg=G")
              vim.fn.winrestview(view)
            end
            return
          end
          vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 2000 })
        end,
      })
    end,
  },
}
