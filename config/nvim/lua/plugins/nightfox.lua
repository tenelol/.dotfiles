return {
  "EdenEast/nightfox.nvim",
  lazy = false,
  name = "nightfox",
  priority = 1000,
  config = function()
    local function apply_glass_highlights()
      local glass = {
        ink = "#e9f2ff",
        muted = "#b9c7d8",
        edge = "#ffffff",
        highlight = "#7cc6ff",
        accent = "#78ffd6",
        dim = "#0a111d",
      }

      local groups = {
        "Normal",
        "NormalNC",
        "SignColumn",
        "EndOfBuffer",
        "MsgArea",
        "FloatBorder",
        "NormalFloat",
        "Pmenu",
        "PmenuSel",
        "PmenuSbar",
        "PmenuThumb",
        "StatusLine",
        "StatusLineNC",
        "TabLine",
        "TabLineSel",
        "TabLineFill",
        "WinSeparator",
      }

      for _, group in ipairs(groups) do
        vim.api.nvim_set_hl(0, group, { bg = "none" })
      end

      vim.api.nvim_set_hl(0, "Normal", { fg = glass.ink, bg = "none" })
      vim.api.nvim_set_hl(0, "NormalNC", { fg = glass.muted, bg = "none" })
      vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = glass.muted, bg = "none" })
      vim.api.nvim_set_hl(0, "MsgArea", { fg = glass.ink, bg = "none" })
      vim.api.nvim_set_hl(0, "FloatBorder", { fg = glass.highlight, bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { fg = glass.ink, bg = "none" })
      vim.api.nvim_set_hl(0, "Pmenu", { fg = glass.ink, bg = "none" })
      vim.api.nvim_set_hl(0, "PmenuSel", { fg = glass.dim, bg = glass.highlight })
      vim.api.nvim_set_hl(0, "PmenuSbar", { bg = "none" })
      vim.api.nvim_set_hl(0, "PmenuThumb", { bg = glass.highlight })
      vim.api.nvim_set_hl(0, "StatusLine", { fg = glass.ink, bg = "none" })
      vim.api.nvim_set_hl(0, "StatusLineNC", { fg = glass.muted, bg = "none" })
      vim.api.nvim_set_hl(0, "TabLine", { fg = glass.muted, bg = "none" })
      vim.api.nvim_set_hl(0, "TabLineSel", { fg = glass.dim, bg = glass.accent })
      vim.api.nvim_set_hl(0, "TabLineFill", { fg = glass.muted, bg = "none" })
      vim.api.nvim_set_hl(0, "WinSeparator", { fg = glass.edge, bg = "none" })
    end

    require("nightfox").setup({
      options = {
        transparent = true, -- ← これが肝心
        dim_inactive = true,
      },
    })
    vim.cmd.colorscheme("nightfox")
    apply_glass_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = apply_glass_highlights,
    })
  end,
}
