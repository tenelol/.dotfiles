local plugin = require("nix-plugin")
local theme = require("core.theme")

return {
  plugin.spec("tokyonight-nvim", {
    lazy = false,
    name = "tokyonight",
    priority = 1000,
    config = function()
      vim.o.background = "dark"

      require("tokyonight").setup({
        style = "storm",
        transparent = true,
        terminal_colors = true,
        dim_inactive = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
          sidebars = "transparent",
          floats = "transparent",
        },
        on_highlights = function(hl, _)
          hl.Normal = { fg = theme.fg, bg = "none" }
          hl.NormalNC = { fg = theme.fg_dark, bg = "none" }
          hl.EndOfBuffer = { fg = theme.fg_gutter, bg = "none" }
          hl.MsgArea = { fg = theme.fg, bg = "none" }
          hl.FloatBorder = { fg = theme.blue, bg = "none" }
          hl.NormalFloat = { fg = theme.fg, bg = "none" }
          hl.Pmenu = { fg = theme.fg, bg = "none" }
          hl.PmenuSel = { fg = theme.fg, bg = theme.bg_selection }
          hl.PmenuSbar = { bg = "none" }
          hl.PmenuThumb = { bg = theme.blue }
          hl.StatusLine = { fg = theme.fg, bg = "none" }
          hl.StatusLineNC = { fg = theme.fg_dark, bg = "none" }
          hl.TabLine = { fg = theme.fg_dark, bg = "none" }
          hl.TabLineSel = { fg = theme.bg, bg = theme.cyan }
          hl.TabLineFill = { fg = theme.fg_gutter, bg = "none" }
          hl.WinSeparator = { fg = theme.fg_gutter, bg = "none" }

          hl.CursorLine = { bg = theme.bg_highlight }
          hl.Visual = { bg = theme.bg_selection }
          hl.Search = { fg = theme.bg, bg = theme.yellow }
          hl.IncSearch = { fg = theme.bg, bg = theme.orange }

          hl.DiagnosticError = { fg = theme.red }
          hl.DiagnosticWarn = { fg = theme.yellow }
          hl.DiagnosticInfo = { fg = theme.cyan }
          hl.DiagnosticHint = { fg = theme.green }

          hl.TelescopeBorder = { fg = theme.blue, bg = "none" }
          hl.TelescopeNormal = { fg = theme.fg, bg = "none" }
          hl.TelescopeSelection = { fg = theme.fg, bg = theme.bg_selection }
          hl.TelescopeMatching = { fg = theme.cyan, bold = true }

          hl.NoiceCmdlinePopupBorder = { fg = theme.blue, bg = "none" }
          hl.NoiceCmdlinePopup = { fg = theme.fg, bg = "none" }
          hl.WhichKeyFloat = { fg = theme.fg, bg = "none" }
        end,
      })
      vim.cmd.colorscheme("tokyonight-storm")
    end,
  }),
}
