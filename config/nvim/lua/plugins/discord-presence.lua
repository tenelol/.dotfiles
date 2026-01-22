return {
  "andweeb/presence.nvim",
  enabled = vim.env.NVIM_DISCORD_PRESENCE == "1",
  config = function()
    require("presence").setup({
      auto_update = true,
      main_image = "neovim",
      neovim_image_text = "Neovim",
    })
  end,
}
