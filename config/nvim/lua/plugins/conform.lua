return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  opts = {
    formatters_by_ft = {
      javascript = { "prettierd", "prettier" },
      javascriptreact = { "prettierd", "prettier" },
      typescript = { "prettierd", "prettier" },
      typescriptreact = { "prettierd", "prettier" },
      json = { "prettierd", "prettier" },
      jsonc = { "prettierd", "prettier" },
      css = { "prettierd", "prettier" },
      html = { "prettierd", "prettier" },
      markdown = { "prettierd", "prettier" },
      astro = { "prettierd", "prettier" },
    },
    format_on_save = function(_bufnr)
      return {
        timeout_ms = 2000,
        lsp_format = "fallback",
      }
    end,
  },
}
