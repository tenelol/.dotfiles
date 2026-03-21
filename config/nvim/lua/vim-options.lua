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

local preview_job_id
local preview_port = 5500

local function open_in_browser(target)
    local opener = vim.fn.has("mac") == 1 and "open" or "xdg-open"
    vim.fn.jobstart({ opener, target }, { detach = true })
end

local function current_file_path()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("No file to open", vim.log.levels.WARN)
        return nil
    end

    return vim.fs.normalize(filepath)
end

local function stop_live_server()
    if preview_job_id == nil then
        return
    end

    local status = vim.fn.jobwait({ preview_job_id }, 0)[1]
    if status == -1 then
        vim.fn.jobstop(preview_job_id)
    end
    preview_job_id = nil
end

local function preview_target()
    local filepath = current_file_path()
    if filepath == nil then
        return nil
    end

    local cwd = vim.fs.normalize(vim.fn.getcwd())
    local root = cwd

    if filepath:sub(1, #cwd) ~= cwd then
        root = vim.fs.dirname(filepath)
    end

    local relative = vim.fs.relpath(root, filepath) or vim.fs.basename(filepath)
    return {
        filepath = filepath,
        root = root,
        relative = relative,
        url = ("http://127.0.0.1:%d/%s"):format(preview_port, relative),
    }
end

local function start_live_server()
    local target = preview_target()
    if target == nil then
        return
    end

    stop_live_server()

    if vim.fn.executable("live-server") == 1 then
        preview_job_id = vim.fn.jobstart({
            "live-server",
            target.root,
            "--host=127.0.0.1",
            ("--port=%d"):format(preview_port),
            "--no-browser",
            "--quiet",
        })
    elseif vim.fn.executable("python3") == 1 then
        preview_job_id = vim.fn.jobstart({
            "python3",
            "-m",
            "http.server",
            tostring(preview_port),
            "--directory",
            target.root,
        })
    else
        vim.notify("live-server or python3 is required for preview", vim.log.levels.ERROR)
        return
    end

    if preview_job_id <= 0 then
        vim.notify("Failed to start preview server", vim.log.levels.ERROR)
        preview_job_id = nil
        return
    end

    vim.defer_fn(function()
        open_in_browser(target.url)
    end, 250)
end

local function open_current_file_in_browser()
    local filepath = current_file_path()
    if filepath == nil then
        return
    end

    open_in_browser(vim.uri_from_fname(filepath))
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = stop_live_server,
})

vim.api.nvim_create_user_command("OpenInBrowser", open_current_file_in_browser, {
    desc = "Open current file in browser",
})
vim.api.nvim_create_user_command("PreviewStart", start_live_server, {
    desc = "Start local preview server for current file",
})
vim.api.nvim_create_user_command("PreviewStop", stop_live_server, {
    desc = "Stop local preview server",
})
vim.api.nvim_create_user_command("LiveServerStart", start_live_server, {
    desc = "Start local preview server for current file",
})
vim.api.nvim_create_user_command("LiveServerStop", stop_live_server, {
    desc = "Stop local preview server",
})
vim.keymap.set("n", "<leader>ob", open_current_file_in_browser, {
    noremap = true,
    silent = true,
    desc = "Open current file in browser",
})
vim.keymap.set("n", "<leader>os", start_live_server, {
    noremap = true,
    silent = true,
    desc = "Start preview server",
})
vim.keymap.set("n", "<leader>oS", stop_live_server, {
    noremap = true,
    silent = true,
    desc = "Stop preview server",
})

vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.winblend = 12
vim.opt.pumblend = 12
vim.opt.number = true

vim.keymap.set('n', '<C-Tab>', '<Cmd>BufferNext<CR>')
vim.keymap.set('n', '<C-S-Tab>', '<Cmd>BufferPrevious<CR>')

-- indentation
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true

vim.filetype.add({
    extension = {
        js = "javascript",
        mjs = "javascript",
        cjs = "javascript",
        jsx = "javascriptreact",
        tsx = "typescriptreact",
    },
})

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
        "sass",
        "scss",
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
