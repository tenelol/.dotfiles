local plugin = require("nix-plugin")
local theme = require("core.theme")

return {
  plugin.spec("noice-nvim", {
    event = "VeryLazy",
    config = function()
      local notify = require("notify")

      notify.setup({
        background_colour = theme.bg,
        render = "compact",
        stages = "fade",
        timeout = 2000,
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
            enabled = false,
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
              kind = "info",
            },
            view = "mini",
          },
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
