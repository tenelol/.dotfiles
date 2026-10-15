-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/presence.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.env.NVIM_DISCORD_PRESENCE = nil
package.loaded["nix-managed-plugins"] = { ["presence-nvim"] = "/test/presence.nvim" }
package.loaded["nix-plugin-modules"] = { "plugins.discord-presence" }
package.loaded["features.web"] = {}
package.loaded["features.platformio"] = {}
require("core.plugin-loader")
-- Without this flag presence.nvim's plugin/ script sets itself up anyway.
assert(vim.g.presence_has_setup == 1, "Disabled presence must block its auto-setup")
print("Disabled Discord presence skips auto-setup: OK")
