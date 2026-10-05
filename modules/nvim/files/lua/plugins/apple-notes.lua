if vim.fn.has("macunix") ~= 1 then
  return {}
end

local plugin = require("nix-plugin")

return {
  plugin.spec("apple-notes-nvim", {
    dependencies = { plugin.dep("telescope-nvim"), plugin.dep("neo-tree-nvim") },
    event = "VeryLazy",
    config = function()
      require("apple-notes").setup()
    end,
  }),
}
