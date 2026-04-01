local plugin = require("nix-plugin")

return {
  plugin.spec("noice-nvim", {
    event = "VeryLazy",
    config = function()
      local notify = require("notify")

      notify.setup({
        background_colour = "#000000",
        render = "compact",
        stages = "fade",
      })

      vim.notify = notify

      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = {
            enabled = true,
            silent = true,
          },
          signature = {
            enabled = true,
          },
        },
        messages = {
          view_search = "virtualtext",
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          lsp_doc_border = true,
        },
        routes = {
          {
            filter = {
              event = "notify",
              find = "No information available",
            },
            opts = { skip = true },
          },
        },
      })
    end,
    dependencies = {
      plugin.dep("nui-nvim"),
      plugin.dep("nvim-notify"),
    },
  }),
}
