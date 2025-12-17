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

vim.keymap.set('n', '<C-Tab>', '<Cmd>BufferNext<CR>')
vim.keymap.set('n', '<C-S-Tab>', '<Cmd>BufferPrevious<CR>')

