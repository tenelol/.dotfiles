if vim.env.NVIM_WEB_WORKFLOW ~= "1" then
    return
end

local project = require("core.project")
local terminal = require("core.terminal")
local autosave_group = vim.api.nvim_create_augroup("WebAutoSave", { clear = true })
local scss_watch_group = vim.api.nvim_create_augroup("ScssWatch", { clear = true })
local preview_job_id
local preview_port = 5500
local scss_watch_job_id
local scss_watch_target
local tsc_watch_terminal
local tsc_watch_root
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

local function path_is_within(root, filepath)
    local normalized_root = vim.fs.normalize(root)
    local normalized_path = vim.fs.normalize(filepath)
    local root_with_sep = normalized_root:sub(-1) == "/" and normalized_root or (normalized_root .. "/")

    return normalized_path == normalized_root or normalized_path:sub(1, #root_with_sep) == root_with_sep
end

local function path_exists(path)
    return uv.fs_stat(vim.fs.normalize(path)) ~= nil
end

local function shell_join(parts)
    local escaped = {}

    for _, part in ipairs(parts) do
        table.insert(escaped, vim.fn.shellescape(part))
    end

    return table.concat(escaped, " ")
end

local function scss_compiler()
    if vim.fn.executable("sass") == 1 then
        return "sass"
    end

    if vim.fn.executable("sassc") == 1 then
        return "sassc"
    end

    return nil
end

local function infer_scss_entrypoint(filepath)
    local normalized = vim.fs.normalize(filepath)
    local basename = vim.fs.basename(normalized)

    if basename:sub(1, 1) ~= "_" then
        return normalized
    end

    local root_limit = project.root(normalized)
    local search_dir = vim.fs.dirname(normalized)
    local candidates = {
        "style.scss",
        "style.sass",
        "main.scss",
        "main.sass",
        "index.scss",
        "index.sass",
    }

    while search_dir ~= nil do
        for _, candidate in ipairs(candidates) do
            local candidate_path = vim.fs.joinpath(search_dir, candidate)
            if uv.fs_stat(candidate_path) ~= nil then
                return vim.fs.normalize(candidate_path)
            end
        end

        if search_dir == root_limit then
            break
        end

        local parent = vim.fs.dirname(search_dir)
        if parent == nil or parent == search_dir then
            break
        end
        search_dir = parent
    end

    return normalized
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

    local root = project.root(filepath)
    if not path_is_within(root, filepath) then
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

    local input = infer_scss_entrypoint(filepath)
    local output = opts.output
    if output == nil or output == "" then
        output = vim.fn.fnamemodify(input, ":r") .. ".css"
    elseif not vim.startswith(output, "/") then
        output = vim.fs.normalize(vim.fn.getcwd() .. "/" .. output)
    else
        output = vim.fs.normalize(output)
    end

    return {
        input = input,
        output = output,
        root = vim.fs.normalize(vim.fs.dirname(input)),
    }
end

local function compile_scss_target(target)
    local compiler = scss_compiler()
    if compiler == nil then
        vim.notify("sass or sassc is required for SCSS compilation", vim.log.levels.ERROR)
        return false
    end

    local cmd
    if compiler == "sass" then
        cmd = { compiler, "--no-source-map", target.input, target.output }
    else
        cmd = { compiler, target.input, target.output }
    end

    local result = vim.system(cmd):wait()
    if result.code == 0 then
        vim.notify(("Compiled %s"):format(target.output), vim.log.levels.INFO)
        return true
    end

    local message = result.stderr ~= "" and result.stderr or "SCSS compile failed"
    vim.notify(message, vim.log.levels.ERROR)
    return false
end

local function scss_compile(opts)
    local target = current_scss_target(opts)
    if target == nil then
        return
    end

    if vim.bo.modified then
        vim.cmd("silent write")
    end

    if scss_compiler() == nil then
        vim.notify("sass or sassc is required for SCSS compilation", vim.log.levels.ERROR)
        return
    end

    compile_scss_target(target)
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
    scss_watch_target = nil
    vim.api.nvim_clear_autocmds({ group = scss_watch_group })
end

local function tsc_watch_command(root)
    if path_exists(vim.fs.joinpath(root, "package.json")) then
        if path_exists(vim.fs.joinpath(root, "pnpm-lock.yaml")) and vim.fn.executable("pnpm") == 1 then
            return { "pnpm", "exec", "tsc", "--watch", "--preserveWatchOutput" }
        end

        if path_exists(vim.fs.joinpath(root, "yarn.lock")) and vim.fn.executable("yarn") == 1 then
            return { "yarn", "exec", "tsc", "--watch", "--preserveWatchOutput" }
        end

        if path_exists(vim.fs.joinpath(root, "package-lock.json")) and vim.fn.executable("npm") == 1 then
            return { "npm", "exec", "tsc", "--", "--watch", "--preserveWatchOutput" }
        end
    end

    if vim.fn.executable("tsc") == 1 then
        return { "tsc", "--watch", "--preserveWatchOutput" }
    end

    return nil
end

local function get_tsc_watch_terminal()
    if tsc_watch_terminal ~= nil then
        return tsc_watch_terminal
    end

    local Terminal = require("toggleterm.terminal").Terminal

    tsc_watch_terminal = Terminal:new({
        id = 92,
        direction = "horizontal",
        size = 10,
        close_on_exit = false,
        dir = project.buffer_root(0),
        display_name = "TypeScript watch",
        on_exit = function()
            vim.schedule(function()
                tsc_watch_terminal = nil
                tsc_watch_root = nil
            end)
        end,
    })

    return tsc_watch_terminal
end

local function stop_tsc_watch()
    if tsc_watch_terminal == nil then
        return
    end

    local term = tsc_watch_terminal
    tsc_watch_terminal = nil
    tsc_watch_root = nil

    local ok, err = pcall(function()
        term:shutdown()
    end)

    if not ok then
        vim.notify(("Failed to stop TypeScript watch: %s"):format(err), vim.log.levels.WARN)
    end
end

local function start_tsc_watch()
    local root = project.buffer_root(0)
    local cmd = tsc_watch_command(root)

    if cmd == nil then
        vim.notify("tsc watch requires TypeScript or a supported package manager", vim.log.levels.ERROR)
        return
    end

    if tsc_watch_terminal ~= nil then
        tsc_watch_terminal.dir = root
        terminal.show(tsc_watch_terminal, { size = 10, direction = "horizontal" })

        if tsc_watch_root == root then
            vim.notify(("TypeScript watch is already running in %s"):format(root), vim.log.levels.INFO)
            return
        end

        stop_tsc_watch()
    end

    local term = get_tsc_watch_terminal()
    tsc_watch_root = root
    term.dir = root
    terminal.show(term, { size = 10, direction = "horizontal" })
    term:send({
        "cd " .. vim.fn.shellescape(root),
        "clear",
        shell_join(cmd),
    }, true)

    vim.notify(("Watching TypeScript in %s"):format(root), vim.log.levels.INFO)
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

    local compiler = scss_compiler()
    if compiler == nil then
        vim.notify("sass or sassc is required for SCSS watch", vim.log.levels.ERROR)
        return
    end

    stop_scss_watch()
    scss_watch_target = target
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = scss_watch_group,
        pattern = { "*.scss", "*.sass" },
        callback = function(args)
            if scss_watch_target == nil then
                return
            end

            local saved = vim.fs.normalize(args.file)
            if path_is_within(scss_watch_target.root, saved) then
                compile_scss_target(scss_watch_target)
            end
        end,
    })

    scss_watch_job_id = vim.fn.jobstart({
        "python3",
        scss_watch_script,
        "--input",
        target.input,
        "--output",
        target.output,
        "--compiler",
        compiler,
        "--root",
        target.root,
    })

    if scss_watch_job_id <= 0 then
        scss_watch_job_id = nil
        vim.notify("Failed to start SCSS watch", vim.log.levels.ERROR)
        return
    end

    compile_scss_target(target)
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
        stop_tsc_watch()
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
vim.api.nvim_create_user_command("TscWatchStart", start_tsc_watch, {
    desc = "Start TypeScript watch in the current project",
})
vim.api.nvim_create_user_command("TscWatchStop", stop_tsc_watch, {
    desc = "Stop TypeScript watch",
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
vim.keymap.set("n", "<leader>tw", start_tsc_watch, {
    noremap = true,
    silent = true,
    desc = "Watch TypeScript",
})
vim.keymap.set("n", "<leader>tW", stop_tsc_watch, {
    noremap = true,
    silent = true,
    desc = "Stop TypeScript watch",
})
