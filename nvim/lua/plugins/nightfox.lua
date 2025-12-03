return {
  "EdenEast/nightfox.nvim",
  lazy = false,
  name = "nightfox",
  priority = 1000,
  config = function()
    require("nightfox").setup({
      options = {
	transparent = False,  -- ← これが肝心
      },
    })
    vim.cmd.colorscheme("nightfox")
  end,
}

