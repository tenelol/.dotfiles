local plugin = require("nix-plugin")

return {
  plugin.spec("lazygit-nvim", {
    dependencies = {
      plugin.dep("plenary-nvim"),
    },
  }),
}
