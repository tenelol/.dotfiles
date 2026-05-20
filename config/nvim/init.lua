local lazypath = dofile(vim.fn.stdpath("config") .. "/lazy-path.lua")
vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    lockfile = vim.fn.stdpath("state") .. "/lazy/lazy-lock.json",
    install = {
        missing = false,
    },
    checker = {
        enabled = false,
    },
    change_detection = {
        enabled = false,
        notify = false,
    },
    pkg = {
        enabled = false,
    },
    rocks = {
        enabled = false,
    },
})

vim.diagnostic.config({
    severity_sort = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    virtual_text = false,
    virtual_lines = false,
    float = {
        border = "rounded",
        header = "",
        prefix = "",
        source = "if_many",
    },
})
