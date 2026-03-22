vim.opt.autoindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.expandtab = true
vim.opt.number = true
vim.opt.pumblend = 12
vim.opt.shiftwidth = 2
vim.opt.signcolumn = "yes"
vim.opt.smartindent = true
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.undofile = true
vim.opt.updatetime = 500
vim.opt.winblend = 12

if vim.fn.has("mac") == 1 then
    vim.g.clipboard = {
        name = "pbcopy",
        copy = {
            ["+"] = "/usr/bin/pbcopy",
            ["*"] = "/usr/bin/pbcopy",
        },
        paste = {
            ["+"] = { "/usr/bin/pbpaste" },
            ["*"] = { "/usr/bin/pbpaste" },
        },
        cache_enabled = 0,
    }
end
