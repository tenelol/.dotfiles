local lazypath = dofile(vim.fn.stdpath("config") .. "/lazy-path.lua")
vim.opt.rtp:prepend(lazypath)


require("vim-options")
require("lazy").setup("plugins")

vim.diagnostic.config({})
