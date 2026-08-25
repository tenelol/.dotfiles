local M = {}

local test_terminal
local project = require("core.project")
local terminal = require("core.terminal")

local function get_terminal()
    if test_terminal ~= nil then
        return test_terminal
    end

    local Terminal = require("toggleterm.terminal").Terminal

    test_terminal = Terminal:new({
        id = 91,
        hidden = true,
        direction = "horizontal",
        size = 10,
        close_on_exit = false,
        dir = project.buffer_root(0),
        display_name = "Tests",
        on_exit = function(_, _, exit_code)
            vim.schedule(function()
                if exit_code == 0 then
                    vim.notify("Tests passed", vim.log.levels.INFO, { title = "vim-test" })
                elseif exit_code ~= nil then
                    vim.notify(("Tests failed (exit %d)"):format(exit_code), vim.log.levels.WARN, { title = "vim-test" })
                end
            end)
        end,
    })

    return test_terminal
end

function M.run(cmd)
    local term = get_terminal()
    local root = project.buffer_root(0)

    term.dir = root
    terminal.show(term, { size = 10, direction = "horizontal" })
    term:send({
        "cd " .. vim.fn.shellescape(root),
        "clear",
        cmd,
    }, true)
end

function M.toggle()
    local term = get_terminal()

    term.dir = project.buffer_root(0)
    if term:is_open() then
        term:close()
        return
    end

    terminal.show(term, { size = 10, direction = "horizontal" })
end

return M
