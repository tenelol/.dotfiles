vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set
local cmd = vim.cmd
local select_all = "<Esc>ggVG"
local is_wsl = vim.fn.has("wsl") == 1

vim.api.nvim_create_user_command("SelectAll", "normal! ggVG", {
  desc = "Select the entire buffer",
})

if not is_wsl then
  map("i", "kj", "<Esc>", { silent = true })
end
map("t", "<C-s>", [[<C-\><C-n>]], { noremap = true, silent = true })
map({ "n", "i", "v" }, "<leader>va", select_all, { silent = true, desc = "Select all" })

if vim.fn.has("mac") == 1 then
  map({ "n", "i", "v" }, "<D-a>", select_all, { silent = true, desc = "Select all" })
end

if is_wsl then
  map({ "n", "i", "v" }, "<C-h>", "<Left>", { noremap = true, silent = true, desc = "Move left" })
  map({ "n", "i", "v" }, "<C-j>", "<Down>", { noremap = true, silent = true, desc = "Move down" })
  map({ "n", "i", "v" }, "<C-k>", "<Up>", { noremap = true, silent = true, desc = "Move up" })
  map({ "n", "i", "v" }, "<C-l>", "<Right>", { noremap = true, silent = true, desc = "Move right" })
else
  map("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
  map("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
  map("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
  map("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
end

map("n", "K", function()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client:supports_method("textDocument/hover") then
      vim.lsp.buf.hover({
        border = "rounded",
        focus = false,
        focusable = false,
        max_width = math.min(80, math.floor(vim.o.columns * 0.6)),
        max_height = math.min(12, math.floor(vim.o.lines * 0.35)),
      })
      return
    end
  end
end, { silent = true, desc = "Hover" })

if not is_wsl then
  map("t", "<C-h>", "<Cmd>wincmd h<CR>", { noremap = true, silent = true })
  map("t", "<C-j>", "<Cmd>wincmd j<CR>", { noremap = true, silent = true })
  map("t", "<C-k>", "<Cmd>wincmd k<CR>", { noremap = true, silent = true })
  map("t", "<C-l>", "<Cmd>wincmd l<CR>", { noremap = true, silent = true })
end

map("n", "<C-Tab>", "<Cmd>BufferLineCycleNext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<C-S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", { silent = true, desc = "Previous buffer" })
map("t", "<C-Tab>", function()
  cmd("BufferLineCycleNext")
end, { silent = true, desc = "Next buffer" })
map("t", "<C-S-Tab>", function()
  cmd("BufferLineCyclePrev")
end, { silent = true, desc = "Previous buffer" })
map("t", "]b", function()
  cmd("BufferLineCycleNext")
end, { silent = true, desc = "Next buffer" })
map("t", "[b", function()
  cmd("BufferLineCyclePrev")
end, { silent = true, desc = "Previous buffer" })
