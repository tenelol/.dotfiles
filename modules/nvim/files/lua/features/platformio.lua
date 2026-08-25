local project = require("core.project")
local terminal = require("core.terminal")

local M = {}

local pio_terminal
local pio_monitor_terminal
local uv = vim.uv or vim.loop

local function path_exists(path)
    return uv.fs_stat(path) ~= nil
end

local function shell_join(parts)
    local escaped = {}

    for _, part in ipairs(parts) do
        table.insert(escaped, vim.fn.shellescape(part))
    end

    return table.concat(escaped, " ")
end

local function platformio_root(opts)
    opts = opts or {}
    local root = project.buffer_root(0)

    if path_exists(vim.fs.joinpath(root, "platformio.ini")) or opts.allow_missing then
        return root
    end

    vim.notify("platformio.ini was not found in this project", vim.log.levels.ERROR, { title = "PlatformIO" })
    return nil
end

local function ensure_platformio()
    if vim.fn.executable("pio") == 1 then
        return true
    end

    vim.notify("PlatformIO CLI was not found in PATH", vim.log.levels.ERROR, { title = "PlatformIO" })
    return false
end

local function get_terminal(kind)
    if kind == "monitor" then
        if pio_monitor_terminal ~= nil then
            return pio_monitor_terminal
        end

        local Terminal = require("toggleterm.terminal").Terminal
        pio_monitor_terminal = Terminal:new({
            id = 94,
            direction = "horizontal",
            size = 10,
            close_on_exit = false,
            dir = project.buffer_root(0),
            display_name = "PlatformIO monitor",
            on_exit = function()
                vim.schedule(function()
                    pio_monitor_terminal = nil
                end)
            end,
        })

        return pio_monitor_terminal
    end

    if pio_terminal ~= nil then
        return pio_terminal
    end

    local Terminal = require("toggleterm.terminal").Terminal
    pio_terminal = Terminal:new({
        id = 93,
        direction = "horizontal",
        size = 10,
        close_on_exit = false,
        dir = project.buffer_root(0),
        display_name = "PlatformIO",
        on_exit = function()
            vim.schedule(function()
                pio_terminal = nil
            end)
        end,
    })

    return pio_terminal
end

local function run_pio(args, opts)
    opts = opts or {}

    if not ensure_platformio() then
        return
    end

    local root = platformio_root({ allow_missing = opts.allow_missing_root })
    if root == nil then
        return
    end

    local term = get_terminal(opts.terminal or "run")
    local cmd = shell_join(vim.list_extend({ "pio" }, args))

    term.dir = root
    terminal.show(term, { size = 10, direction = "horizontal" })
    term:send({
        "cd " .. vim.fn.shellescape(root),
        "clear",
        cmd,
    }, true)
end

function M.build()
    run_pio({ "run" })
end

function M.upload()
    run_pio({ "run", "-t", "upload" })
end

function M.monitor()
    run_pio({ "device", "monitor" }, { terminal = "monitor" })
end

function M.compiledb()
    run_pio({ "run", "-t", "compiledb" })
end

function M.clean()
    run_pio({ "run", "-t", "clean" })
end

function M.init()
    vim.ui.input({ prompt = "PlatformIO board id: " }, function(board)
        if board == nil or board == "" then
            return
        end

        run_pio({ "project", "init", "--board", board }, { allow_missing_root = true })
    end)
end

vim.api.nvim_create_user_command("PioBuild", M.build, {
    desc = "Build the current PlatformIO project",
})
vim.api.nvim_create_user_command("PioUpload", M.upload, {
    desc = "Upload the current PlatformIO project",
})
vim.api.nvim_create_user_command("PioMonitor", M.monitor, {
    desc = "Open the PlatformIO serial monitor",
})
vim.api.nvim_create_user_command("PioCompiledb", M.compiledb, {
    desc = "Generate compile_commands.json with PlatformIO",
})
vim.api.nvim_create_user_command("PioClean", M.clean, {
    desc = "Clean the current PlatformIO project",
})
vim.api.nvim_create_user_command("PioInit", M.init, {
    desc = "Initialize a PlatformIO project by board id",
})

vim.keymap.set("n", "<leader>pb", M.build, {
    noremap = true,
    silent = true,
    desc = "Build PlatformIO project",
})
vim.keymap.set("n", "<leader>pu", M.upload, {
    noremap = true,
    silent = true,
    desc = "Upload PlatformIO project",
})
vim.keymap.set("n", "<leader>pm", M.monitor, {
    noremap = true,
    silent = true,
    desc = "Open PlatformIO monitor",
})
vim.keymap.set("n", "<leader>pc", M.compiledb, {
    noremap = true,
    silent = true,
    desc = "Generate compile database",
})
vim.keymap.set("n", "<leader>pi", M.init, {
    noremap = true,
    silent = true,
    desc = "Initialize PlatformIO project",
})

return M
