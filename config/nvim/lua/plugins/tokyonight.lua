local plugin = require("nix-plugin")
local theme = require("core.theme")

local function set_highlights(hl, groups, spec)
  for _, group in ipairs(groups) do
    hl[group] = spec
  end
end

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
        on_colors = function(c)
          local white_keys = { "fg", "fg_dark", "fg_float", "fg_sidebar" }
          local blue_keys = {
            "blue",
            "blue0",
            "blue1",
            "blue2",
            "blue5",
            "blue6",
            "blue7",
            "comment",
            "cyan",
            "dark3",
            "dark5",
            "fg_gutter",
            "green",
            "green1",
            "green2",
            "magenta",
            "magenta2",
            "orange",
            "purple",
            "red",
            "red1",
            "teal",
            "yellow",
            "error",
            "todo",
            "warning",
            "info",
            "hint",
          }

          for _, key in ipairs(white_keys) do
            c[key] = theme.fg
          end
          for _, key in ipairs(blue_keys) do
            c[key] = theme.blue
          end

          c.border_highlight = theme.blue
          c.bg_visual = theme.bg_selection
          c.bg_search = theme.blue
          c.diff = {
            add = theme.bg_selection,
            delete = theme.bg_selection,
            change = theme.bg_selection,
            text = theme.blue,
          }
          c.git = {
            add = theme.blue,
            change = theme.blue,
            delete = theme.blue,
            ignore = theme.blue,
          }
          c.rainbow = {
            theme.blue,
            theme.fg,
          }
          c.terminal = {
            black = theme.bg,
            black_bright = theme.blue,
            red = theme.blue,
            red_bright = theme.blue,
            green = theme.blue,
            green_bright = theme.blue,
            yellow = theme.blue,
            yellow_bright = theme.blue,
            blue = theme.blue,
            blue_bright = theme.blue,
            magenta = theme.blue,
            magenta_bright = theme.blue,
            cyan = theme.blue,
            cyan_bright = theme.blue,
            white = theme.fg,
            white_bright = theme.fg,
          }
        end,
        on_highlights = function(hl, _)
          set_highlights(hl, {
            "Boolean",
            "Character",
            "Comment",
            "Constant",
            "Delimiter",
            "Float",
            "Normal",
            "NormalFloat",
            "MsgArea",
            "Identifier",
            "Number",
            "String",
            "StorageClass",
            "Structure",
            "Type",
            "Typedef",
            "IblIndent",
            "IblWhitespace",
            "NonText",
            "Whitespace",
            "@boolean",
            "@character",
            "@comment",
            "@constant",
            "@constant.builtin",
            "@constant.macro",
            "@module",
            "@number",
            "@number.float",
            "@string",
            "@string.escape",
            "@string.regex",
            "@type",
            "@type.builtin",
            "@variable",
            "@variable.builtin",
            "@variable.member",
            "@property",
            "@punctuation",
            "@punctuation.bracket",
            "@punctuation.delimiter",
            "@punctuation.special",
            "@text",
            "@text.literal",
          }, { fg = theme.fg, bg = "none" })

          set_highlights(hl, {
            "Conditional",
            "Debug",
            "Define",
            "Exception",
            "Function",
            "Include",
            "Keyword",
            "Label",
            "Macro",
            "Operator",
            "PreCondit",
            "PreProc",
            "Repeat",
            "Special",
            "SpecialChar",
            "SpecialComment",
            "Statement",
            "Tag",
            "Todo",
            "@constructor",
            "@function",
            "@function.builtin",
            "@function.call",
            "@function.macro",
            "@keyword",
            "@keyword.conditional",
            "@keyword.exception",
            "@keyword.function",
            "@keyword.import",
            "@keyword.operator",
            "@keyword.repeat",
            "@label",
            "@operator",
            "@tag",
            "@tag.attribute",
            "@tag.delimiter",
          }, { fg = theme.blue, bg = "none" })

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
          hl.IblIndent = { fg = theme.fg, bg = "none" }
          hl.IblScope = { fg = theme.fg, bg = "none" }
          hl.IblWhitespace = { fg = theme.fg, bg = "none" }

          hl.CursorLine = { bg = theme.bg_highlight }
          hl.Visual = { bg = theme.bg_selection }
          hl.Search = { fg = theme.fg, bg = theme.blue }
          hl.IncSearch = { fg = theme.fg, bg = theme.blue }

          hl.DiagnosticError = { fg = theme.red }
          hl.DiagnosticWarn = { fg = theme.yellow }
          hl.DiagnosticInfo = { fg = theme.cyan }
          hl.DiagnosticHint = { fg = theme.green }
          hl.Error = { fg = theme.blue }
          hl.DiffAdd = { fg = theme.fg, bg = theme.bg_selection }
          hl.DiffChange = { fg = theme.fg, bg = theme.bg_selection }
          hl.DiffDelete = { fg = theme.blue, bg = theme.bg_selection }
          hl.DiffText = { fg = theme.fg, bg = theme.blue }

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
