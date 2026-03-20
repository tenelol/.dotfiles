local plugin = require("nix-plugin")

return {
	plugin.spec("smear-cursor-nvim", {
  init = function()
    require("smear_cursor").setup()
  end,
})
}
