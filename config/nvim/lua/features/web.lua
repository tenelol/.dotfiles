if vim.env.NVIM_WEB_WORKFLOW ~= "1" then
    return
end

local autosave_group = vim.api.nvim_create_augroup("WebAutoSave", { clear = true })
local preview_job_id
local preview_port = 5500
local scss_watch_job_id
local uv = vim.uv or vim.loop
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
local preview_script = vim.fs.normalize(vim.fn.stdpath("config") .. "/lua/live_preview_server.py")
local scss_watch_script = vim.fs.normalize(vim.fn.stdpath("config") .. "/lua/scss_watch.py")

local function open_in_browser(target)
    local opener = vim.fn.has("mac") == 1 and "open" or "xdg-open"

    if vim.fn.executable(opener) ~= 1 then
        vim.notify(("Browser opener %s is not available"):format(opener), vim.log.levels.ERROR)
        return
    end

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

    if vim.fn.executable("python3") ~= 1 or uv.fs_stat(preview_script) == nil then
        vim.notify("python3 and live_preview_server.py are required for preview", vim.log.levels.ERROR)
        return
    end

    preview_job_id = vim.fn.jobstart({
        "python3",
        preview_script,
        "--port",
        tostring(preview_port),
        "--root",
        target.root,
    })

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

local function current_scss_target(opts)
    opts = opts or {}
    local filepath = current_file_path()
    if filepath == nil then
        return nil
    end

    local ext = vim.fn.fnamemodify(filepath, ":e")
    if ext ~= "scss" and ext ~= "sass" then
        vim.notify("Current file is not an SCSS/Sass file", vim.log.levels.WARN)
        return nil
    end

    local output = opts.output
    if output == nil or output == "" then
        output = vim.fn.fnamemodify(filepath, ":r") .. ".css"
    elseif not vim.startswith(output, "/") then
        output = vim.fs.normalize(vim.fn.getcwd() .. "/" .. output)
    else
        output = vim.fs.normalize(output)
    end

    return {
        input = vim.fs.normalize(filepath),
        output = output,
        root = vim.fs.normalize(vim.fs.dirname(filepath)),
    }
end

local function scss_compile(opts)
    local target = current_scss_target(opts)
    if target == nil then
        return
    end

    if vim.bo.modified then
        vim.cmd("silent write")
    end

    if vim.fn.executable("sassc") ~= 1 then
        vim.notify("sassc is required for SCSS compilation", vim.log.levels.ERROR)
        return
    end

    local result = vim.system({ "sassc", target.input, target.output }):wait()
    if result.code == 0 then
        vim.notify(("Compiled %s"):format(target.output), vim.log.levels.INFO)
        return
    end

    local message = result.stderr ~= "" and result.stderr or "SCSS compile failed"
    vim.notify(message, vim.log.levels.ERROR)
end

local function stop_scss_watch()
    if scss_watch_job_id == nil then
        return
    end

    local status = vim.fn.jobwait({ scss_watch_job_id }, 0)[1]
    if status == -1 then
        vim.fn.jobstop(scss_watch_job_id)
    end
    scss_watch_job_id = nil
end

local function start_scss_watch(opts)
    local target = current_scss_target(opts)
    if target == nil then
        return
    end

    if vim.bo.modified then
        vim.cmd("silent write")
    end

    if vim.fn.executable("python3") ~= 1 or uv.fs_stat(scss_watch_script) == nil then
        vim.notify("python3 and scss_watch.py are required for SCSS watch", vim.log.levels.ERROR)
        return
    end

    if vim.fn.executable("sassc") ~= 1 then
        vim.notify("sassc is required for SCSS watch", vim.log.levels.ERROR)
        return
    end

    stop_scss_watch()
    scss_watch_job_id = vim.fn.jobstart({
        "python3",
        scss_watch_script,
        "--input",
        target.input,
        "--output",
        target.output,
        "--root",
        target.root,
    })

    if scss_watch_job_id <= 0 then
        scss_watch_job_id = nil
        vim.notify("Failed to start SCSS watch", vim.log.levels.ERROR)
        return
    end

    vim.notify(("Watching %s -> %s"):format(target.input, target.output), vim.log.levels.INFO)
end

local function autosave_buffer(bufnr)
    if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
        return
    end

    if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modified then
        return
    end

    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent noautocmd write")
    end)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        stop_live_server()
        stop_scss_watch()
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = autosave_group,
    pattern = web_filetypes,
    callback = function(args)
        if vim.b[args.buf].web_autosave_initialized then
            return
        end

        vim.b[args.buf].web_autosave_initialized = true

        vim.api.nvim_create_autocmd({ "InsertLeave", "CursorHold", "CursorHoldI" }, {
            group = autosave_group,
            buffer = args.buf,
            callback = function()
                autosave_buffer(args.buf)
            end,
        })
    end,
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
vim.api.nvim_create_user_command("ScssCompile", function(args)
    scss_compile({ output = args.args })
end, {
    desc = "Compile current SCSS/Sass file",
    nargs = "?",
})
vim.api.nvim_create_user_command("ScssWatchStart", function(args)
    start_scss_watch({ output = args.args })
end, {
    desc = "Watch current SCSS/Sass file and compile to CSS",
    nargs = "?",
})
vim.api.nvim_create_user_command("ScssWatchStop", stop_scss_watch, {
    desc = "Stop SCSS watch",
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
vim.keymap.set("n", "<leader>lc", scss_compile, {
    noremap = true,
    silent = true,
    desc = "Compile SCSS",
})
vim.keymap.set("n", "<leader>lw", start_scss_watch, {
    noremap = true,
    silent = true,
    desc = "Watch SCSS",
})
vim.keymap.set("n", "<leader>lW", stop_scss_watch, {
    noremap = true,
    silent = true,
    desc = "Stop SCSS watch",
})
