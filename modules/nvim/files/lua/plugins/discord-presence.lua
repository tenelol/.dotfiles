local plugin = require("nix-plugin")
local enabled = vim.env.NVIM_DISCORD_PRESENCE == "1"

-- presence.nvim's plugin/ script sets itself up unless this flag exists. Left
-- running without Discord, it spawns git and leaks sockets on every window
-- switch until Neovim hits the fd limit and aborts.
if not enabled then
  vim.g.presence_has_setup = 1
end

return {
  plugin.spec("presence-nvim", {
  enabled = enabled,
  config = function()
    require("presence").setup({
      auto_update = true,
      main_image = "neovim",
      neovim_image_text = "Neovim",
    })
  end,
  }),
}
