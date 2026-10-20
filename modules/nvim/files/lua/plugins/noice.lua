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
        stages = "fade_in_slide_out",
        fps = 60,
        timeout = 2000,
        -- Errors still pop up, but from the bottom corner, clear of the code.
        top_down = false,
        on_open = function(win)
          -- Notifications fade in where they rest, so lock onto that spot.
          require("core.motion").lock(require("core.motion").window_rect(win), { spread = 0.6 })
        end,
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
        -- Everyday messages ("written", plugin info) go to the one-line corner view
        -- instead of popups over the code; only errors get a popup.
        messages = {
          view = "mini",
          view_warn = "mini",
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
          -- First match wins, so the skip has to come before the catch-all below.
          {
            filter = {
              event = "notify",
              find = "No information available",
            },
            opts = { skip = true },
          },
          {
            filter = {
              event = "notify",
              any = { { kind = "info" }, { kind = "debug" }, { kind = "trace" }, { kind = "warn" } },
            },
            view = "mini",
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
