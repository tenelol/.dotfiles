local plugin = require("nix-plugin")

return {
  plugin.spec("conform-nvim", {
    event = { "BufWritePre" },
    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({
            async = true,
            lsp_format = "fallback",
          })
        end,
        desc = "Format buffer",
      },
    },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          javascript = { "prettierd", "prettier" },
          javascriptreact = { "prettierd", "prettier" },
          typescript = { "prettierd", "prettier" },
          typescriptreact = { "prettierd", "prettier" },
          json = { "prettierd", "prettier" },
          jsonc = { "prettierd", "prettier" },
          css = { "prettierd", "prettier" },
          sass = { "prettierd", "prettier" },
          scss = { "prettierd", "prettier" },
          html = { "prettierd", "prettier" },
          markdown = { "prettierd", "prettier" },
          astro = { "prettierd", "prettier" },
          lua = { "stylua" },
          c = { "clang_format" },
          cpp = { "clang_format" },
          objc = { "clang_format" },
          objcpp = { "clang_format" },
          nix = { "nixfmt" },
          go = { "goimports", "gofumpt", "gofmt" },
        },
        format_on_save = function(_bufnr)
          return {
            timeout_ms = 2000,
            lsp_format = "fallback",
          }
        end,
      })
    end,
  }),
}
