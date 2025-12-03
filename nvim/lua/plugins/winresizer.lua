return {
  "simeji/winresizer",

  event = "VeryLazy",

  config = function()

    vim.keymap.set("n", "<C-w>e", ":WinResizerStartResize<CR>", { silent = true })
  end,
}

