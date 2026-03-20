local plugin = require("nix-plugin")

return {
  plugin.spec("nvim-lspconfig", {
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
        "ts_ls",
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

    end,
  }),
}
