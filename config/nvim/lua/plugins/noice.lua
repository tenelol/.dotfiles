local plugin = require("nix-plugin")
local theme = require("core.theme")

return {
  plugin.spec("noice-nvim", {
    event = "VeryLazy",
    config = function()
      local notify = require("notify")

      local function notification_width()
        return math.min(80, math.max(30, math.floor(vim.o.columns * 0.45)))
      end

      local function notification_height()
        return math.min(8, math.max(4, math.floor(vim.o.lines * 0.25)))
      end

      notify.setup({
        background_colour = theme.bg,
        max_height = notification_height,
        max_width = notification_width,
        minimum_width = 24,
        render = "wrapped-compact",
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
        views = {
          mini = {
            size = {
              max_height = 4,
              max_width = 60,
            },
          },
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
