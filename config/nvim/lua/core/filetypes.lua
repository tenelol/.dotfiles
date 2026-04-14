vim.filetype.add({
    extension = {
        js = "javascript",
        mjs = "javascript",
        cjs = "javascript",
        jsx = "javascriptreact",
        tsx = "typescriptreact",
        ino = "cpp",
    },
})

local indent_group = vim.api.nvim_create_augroup("IndentSettings", { clear = true })
local web_filetypes = {
    "html",
    "css",
    "sass",
    "scss",
    "javascript",
    "typescript",
    "typescriptreact",
    "javascriptreact",
    "astro",
}

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
    pattern = vim.list_extend(vim.deepcopy(web_filetypes), { "nix", "json", "jsonc", "markdown" }),
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
