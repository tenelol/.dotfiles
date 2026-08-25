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
          keywords = {},
          functions = {},
          variables = {},
          sidebars = "transparent",
          floats = "transparent",
        },
        on_colors = function(c)
          c.fg = theme.fg
          c.fg_dark = theme.fg_dark
          c.fg_float = theme.fg
          c.fg_sidebar = theme.fg_dark
          c.fg_gutter = theme.fg_gutter
          c.comment = theme.comment
          c.bg = theme.bg
          c.bg_dark = theme.bg_dark
          c.bg_float = theme.bg_dark
          c.bg_highlight = theme.bg_highlight
          c.bg_sidebar = theme.bg_dark
          c.blue = theme.blue
          c.blue0 = theme.blue0
          c.blue1 = theme.blue0
          c.blue2 = theme.blue0
          c.blue5 = theme.blue0
          c.blue6 = theme.blue0
          c.cyan = theme.cyan
          c.green = theme.green
          c.green1 = theme.blue0
          c.green2 = theme.blue0
          c.magenta = theme.magenta
          c.orange = theme.orange
          c.purple = theme.purple
          c.red = theme.red
          c.teal = theme.blue0
          c.yellow = theme.yellow
          c.error = theme.red
          c.warning = theme.yellow
          c.info = theme.cyan
          c.hint = theme.green
          c.todo = theme.magenta
          c.border_highlight = theme.blue
          c.bg_visual = theme.bg_selection
          c.bg_search = theme.yellow
          c.diff = {
            add = "#183242",
            delete = "#202a45",
            change = "#243149",
            text = "#2b3f5c",
          }
          c.git = {
            add = theme.green,
            change = theme.yellow,
            delete = theme.red,
            ignore = theme.fg_gutter,
          }
          c.rainbow = {
            theme.fg_dark,
            theme.blue0,
            theme.blue,
            theme.cyan,
            theme.fg,
            theme.blue,
          }
          c.terminal = {
            black = theme.bg,
            black_bright = theme.fg_gutter,
            red = theme.red,
            red_bright = theme.red,
            green = theme.green,
            green_bright = theme.green,
            yellow = theme.yellow,
            yellow_bright = theme.yellow,
            blue = theme.blue,
            blue_bright = theme.blue,
            magenta = theme.magenta,
            magenta_bright = theme.magenta,
            cyan = theme.cyan,
            cyan_bright = theme.cyan,
            white = theme.fg,
            white_bright = theme.fg_bright,
          }
        end,
        on_highlights = function(hl, _)
          set_highlights(hl, {
            "Comment",
            "@comment",
            "@comment.documentation",
          }, { fg = theme.comment, bg = "none", italic = true })

          set_highlights(hl, {
            "String",
            "Character",
            "@string",
            "@string.escape",
            "@string.regex",
            "@character",
          }, { fg = theme.fg_dark, bg = "none" })

          set_highlights(hl, {
            "Boolean",
            "Constant",
            "Float",
            "Number",
            "@boolean",
            "@constant",
            "@constant.builtin",
            "@constant.macro",
            "@number",
            "@number.float",
          }, { fg = theme.fg_dark, bg = "none" })

          set_highlights(hl, {
            "Type",
            "StorageClass",
            "Structure",
            "Typedef",
            "@type",
            "@type.definition",
            "@constructor",
          }, { fg = theme.blue0, bg = "none" })

          set_highlights(hl, {
            "@type.builtin",
            "@lsp.type.class",
            "@lsp.type.enum",
            "@lsp.type.interface",
            "@lsp.type.namespace",
            "@lsp.type.type",
            "@lsp.type.typeParameter",
            "@lsp.typemod.type.defaultLibrary",
            "@lsp.typemod.typeAlias.defaultLibrary",
          }, { fg = theme.cyan, bg = "none" })

          set_highlights(hl, {
            "Identifier",
            "@module",
            "@variable",
            "@variable.builtin",
            "@variable.member",
            "@property",
            "@text",
            "@text.literal",
            "@lsp.type.function",
            "@lsp.type.method",
            "@lsp.type.parameter",
            "@lsp.type.property",
            "@lsp.type.variable",
          }, { fg = theme.fg, bg = "none" })

          set_highlights(hl, {
            "@punctuation",
            "@punctuation.bracket",
            "@punctuation.delimiter",
            "@punctuation.special",
            "Delimiter",
            "NonText",
            "Whitespace",
          }, { fg = theme.fg_gutter, bg = "none" })

          set_highlights(hl, {
            "Debug",
            "Function",
            "@constructor",
            "@function",
            "@function.builtin",
            "@function.call",
            "@function.macro",
            "@function.method",
            "@function.method.call",
            "@method",
            "@method.call",
          }, { fg = theme.fg, bg = "none" })

          set_highlights(hl, {
            "Conditional",
            "Define",
            "Exception",
            "Include",
            "Keyword",
            "Label",
            "Macro",
            "PreCondit",
            "PreProc",
            "Repeat",
            "Statement",
            "@keyword",
            "@keyword.coroutine",
            "@keyword.conditional",
            "@keyword.debug",
            "@keyword.directive",
            "@keyword.directive.define",
            "@keyword.exception",
            "@keyword.function",
            "@keyword.import",
            "@keyword.modifier",
            "@keyword.operator",
            "@keyword.repeat",
            "@keyword.return",
            "@keyword.type",
            "@label",
          }, { fg = theme.fg_dark, bg = "none" })

          set_highlights(hl, {
            "Operator",
            "@operator",
          }, { fg = theme.fg_dark, bg = "none" })

          set_highlights(hl, {
            "Special",
            "SpecialChar",
            "SpecialComment",
            "@tag",
            "@tag.attribute",
            "@tag.delimiter",
          }, { fg = theme.cyan, bg = "none" })

          set_highlights(hl, {
            "@attribute",
            "@lsp.type.decorator",
          }, { fg = theme.blue0, bg = "none" })

          hl.Todo = { fg = theme.yellow, bg = theme.bg_highlight, bold = true }

          hl.Normal = { fg = theme.fg, bg = "none" }
          hl.NormalNC = { fg = theme.fg_dark, bg = "none" }
          hl.EndOfBuffer = { fg = theme.fg_gutter, bg = "none" }
          hl.MsgArea = { fg = theme.fg, bg = "none" }
          hl.FloatBorder = { fg = theme.fg_gutter, bg = "none" }
          hl.NormalFloat = { fg = theme.fg, bg = "none" }
          hl.Pmenu = { fg = theme.fg, bg = "none" }
          hl.PmenuSel = { fg = theme.fg, bg = theme.bg_selection }
          hl.PmenuSbar = { bg = "none" }
          hl.PmenuThumb = { bg = theme.blue }
          hl.StatusLine = { fg = theme.fg, bg = "none" }
          hl.StatusLineNC = { fg = theme.fg_dark, bg = "none" }
          hl.TabLine = { fg = theme.fg_dark, bg = "none" }
          hl.TabLineSel = { fg = theme.fg_bright, bg = theme.bg_highlight, bold = true }
          hl.TabLineFill = { fg = theme.fg_gutter, bg = "none" }
          hl.WinSeparator = { fg = theme.fg_gutter, bg = "none" }
          hl.IblIndent = { fg = theme.ibl_indent, bg = "none" }
          hl.IblScope = { fg = theme.ibl_scope, bg = "none" }
          hl.IblWhitespace = { fg = theme.ibl_indent, bg = "none" }

          hl.CursorLine = { bg = theme.bg_highlight }
          hl.CursorLineNr = { fg = theme.fg_bright, bold = true }
          hl.Visual = { bg = theme.bg_selection }
          hl.Search = { fg = theme.bg_dark, bg = theme.yellow }
          hl.IncSearch = { fg = theme.bg_dark, bg = theme.orange }

          hl.DiagnosticError = { fg = theme.red, bold = true }
          hl.DiagnosticWarn = { fg = theme.yellow }
          hl.DiagnosticInfo = { fg = theme.cyan }
          hl.DiagnosticHint = { fg = theme.fg_dark }
          hl.DiagnosticSignError = { fg = theme.red, bg = "none", bold = true }
          hl.DiagnosticSignWarn = { fg = theme.yellow, bg = "none", bold = true }
          hl.DiagnosticSignInfo = { fg = theme.cyan, bg = "none" }
          hl.DiagnosticSignHint = { fg = theme.fg_dark, bg = "none" }
          hl.DiagnosticUnderlineError = { sp = theme.red, undercurl = true }
          hl.DiagnosticUnderlineWarn = { sp = theme.yellow, undercurl = true }
          hl.Error = { fg = theme.red, bold = true }
          hl.DiffAdd = { fg = theme.green, bg = "#183242" }
          hl.DiffChange = { fg = theme.yellow, bg = "#243149" }
          hl.DiffDelete = { fg = theme.red, bg = "#202a45" }
          hl.DiffText = { fg = theme.fg, bg = "#2b3f5c" }

          hl.TelescopeBorder = { fg = theme.blue, bg = "none" }
          hl.TelescopeNormal = { fg = theme.fg, bg = "none" }
          hl.TelescopeSelection = { fg = theme.fg, bg = theme.bg_selection }
          hl.TelescopeMatching = { fg = theme.cyan, bold = true }

          hl.NeoTreeDirectoryIcon = { fg = theme.blue0, bg = "none" }
          hl.NeoTreeDirectoryName = { fg = theme.fg_dark, bg = "none" }
          hl.NeoTreeFileIcon = { fg = theme.blue0, bg = "none" }
          hl.NeoTreeFileName = { fg = theme.fg_dark, bg = "none" }
          hl.NeoTreeFileNameOpened = { fg = theme.fg_bright, bg = "none", bold = true }
          hl.NeoTreeRootName = { fg = theme.fg_bright, bg = "none", bold = true, italic = true }
          hl.NeoTreeDiagnosticError = { fg = theme.red, bg = "none", bold = true }
          hl.NeoTreeDiagnosticWarn = { fg = theme.yellow, bg = "none", bold = true }
          hl.NeoTreeDiagnosticInfo = { fg = theme.cyan, bg = "none" }
          hl.NeoTreeDiagnosticHint = { fg = theme.fg_dark, bg = "none" }
          hl.NeoTreeGitAdded = { fg = theme.cyan, bg = "none" }
          hl.NeoTreeGitConflict = { fg = theme.red, bg = "none", bold = true }
          hl.NeoTreeGitDeleted = { fg = theme.red, bg = "none" }
          hl.NeoTreeGitIgnored = { fg = theme.comment, bg = "none" }
          hl.NeoTreeGitModified = { fg = theme.fg_gutter, bg = "none" }
          hl.NeoTreeGitRenamed = { fg = theme.blue0, bg = "none" }
          hl.NeoTreeGitStaged = { fg = theme.cyan, bg = "none" }
          hl.NeoTreeGitUntracked = { fg = theme.fg_gutter, bg = "none" }
          hl.NeoTreeGitUnstaged = { fg = theme.fg_gutter, bg = "none" }
          hl.NeoTreeModified = { fg = theme.fg_dark, bg = "none" }

          hl.NoiceCmdlinePopupBorder = { fg = theme.blue, bg = "none" }
          hl.NoiceCmdlinePopup = { fg = theme.fg, bg = "none" }
          hl.WhichKeyFloat = { fg = theme.fg, bg = "none" }
        end,
      })
      vim.cmd.colorscheme("tokyonight-storm")
    end,
  }),
}
