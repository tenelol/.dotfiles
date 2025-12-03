local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


require("vim-options")
require("lazy").setup("plugins")


require("mason").setup()

require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",
    "basedpyright",
    "gopls",
    "nil_ls",
  },
  automatic_installation = true,
})

local servers = { "lua_ls", "basedpyright", "gopls", "nil_ls" }

for _, server in ipairs(servers) do
  vim.lsp.enable(server)
end

vim.diagnostic.config({})

