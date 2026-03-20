local plugin = require("nix-plugin")

return {
  plugin.spec("nvim-cmp", {
    event = { "InsertEnter", "CmdlineEnter" },
    config = function ()
      local cmp = require("cmp")
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
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
}
