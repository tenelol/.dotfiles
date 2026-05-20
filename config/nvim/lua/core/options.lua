vim.opt.autoindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.hidden = true
vim.opt.ignorecase = true
vim.opt.number = true
vim.opt.pumblend = 12
vim.opt.relativenumber = false
vim.opt.fillchars:append({ eob = " " })
vim.opt.scrolloff = 8
vim.opt.shiftwidth = 2
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.softtabstop = 2
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.sidescrolloff = 8
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.timeoutlen = 300
vim.opt.undofile = true
vim.opt.updatetime = 250
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
