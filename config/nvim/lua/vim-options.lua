-- leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--keymap
vim.keymap.set("i", "kj", "<ESC>", { silent = true })
vim.keymap.set('t', '<C-s>', [[<C-\><C-n>]], { noremap = true, silent = true })

vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

vim.keymap.set("t", "<C-h>", "<Cmd>wincmd h<CR>", { noremap = true, silent = true })
vim.keymap.set("t", "<C-j>", "<Cmd>wincmd j<CR>", { noremap = true, silent = true })
vim.keymap.set("t", "<C-k>", "<Cmd>wincmd k<CR>", { noremap = true, silent = true })
vim.keymap.set("t", "<C-l>", "<Cmd>wincmd l<CR>", { noremap = true, silent = true })

vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.winblend = 12
vim.opt.pumblend = 12
vim.opt.number = true

vim.keymap.set('n', '<C-Tab>', '<Cmd>BufferNext<CR>')
vim.keymap.set('n', '<C-S-Tab>', '<Cmd>BufferPrevious<CR>')

-- indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true

local indent_group = vim.api.nvim_create_augroup("IndentSettings", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = { "python" },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = {
    "nix",
    "html",
    "css",
    "javascript",
    "typescript",
    "typescriptreact",
    "javascriptreact",
    "json",
    "jsonc",
    "markdown",
    "astro",
  },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = indent_group,
  pattern = { "go" },
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 0
  end,
})
