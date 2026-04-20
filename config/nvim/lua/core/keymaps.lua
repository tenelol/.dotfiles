vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set
local cmd = vim.cmd
local select_all = "<Esc>ggVG"

map("i", "kj", "<Esc>", { silent = true })
map("t", "<C-s>", [[<C-\><C-n>]], { noremap = true, silent = true })
map({ "n", "i", "v" }, "<leader>va", select_all, { silent = true, desc = "Select all" })

if vim.fn.has("mac") == 1 then
  map({ "n", "i", "v" }, "<D-a>", select_all, { silent = true, desc = "Select all" })
end

map("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
map("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
map("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
map("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

map("t", "<C-h>", "<Cmd>wincmd h<CR>", { noremap = true, silent = true })
map("t", "<C-j>", "<Cmd>wincmd j<CR>", { noremap = true, silent = true })
map("t", "<C-k>", "<Cmd>wincmd k<CR>", { noremap = true, silent = true })
map("t", "<C-l>", "<Cmd>wincmd l<CR>", { noremap = true, silent = true })

map("n", "<C-Tab>", "<Cmd>BufferNext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<C-S-Tab>", "<Cmd>BufferPrevious<CR>", { silent = true, desc = "Previous buffer" })
map("t", "<C-Tab>", function() cmd("BufferNext") end, { silent = true, desc = "Next buffer" })
map("t", "<C-S-Tab>", function() cmd("BufferPrevious") end, { silent = true, desc = "Previous buffer" })
map("t", "]b", function() cmd("BufferNext") end, { silent = true, desc = "Next buffer" })
map("t", "[b", function() cmd("BufferPrevious") end, { silent = true, desc = "Previous buffer" })
