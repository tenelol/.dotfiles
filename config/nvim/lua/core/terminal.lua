local project = require("core.project")

local M = {}

local float_term
local shell_term
local cli_terms = {}

local function project_root()
    return project.buffer_root(0)
end

local function terminal_module()
    return require("toggleterm.terminal")
end

local function vertical_size(ratio)
    local columns = vim.o.columns
    local preferred = math.floor(columns * ratio)
    local maximum = math.max(20, columns - 20)

    return math.min(math.max(40, preferred), maximum)
end

local function sorted_terminals()
    local terminal = terminal_module()
    local terms = terminal.get_all()

    table.sort(terms, function(left, right)
        return left.id < right.id
    end)

    return terminal, terms
end

local function terminal_index(terms, terminal_id)
    if terminal_id == nil then
        return nil
    end

    for index, term in ipairs(terms) do
        if term.id == terminal_id then
            return index
        end
    end

    return nil
end

local function terminal_by_id(terms, terminal_id)
    if terminal_id == nil then
        return nil
    end

    for _, term in ipairs(terms) do
        if term.id == terminal_id then
            return term
        end
    end

    return nil
end

local function terminal_label(term)
    local name = term.display_name or ("Terminal " .. term.id)
    local direction = term.direction or "horizontal"

    return ("[%d] %s (%s)"):format(term.id, name, direction)
end

local function default_size(term, direction)
    direction = direction or term.direction

    if direction == "vertical" then
        return vertical_size(0.4)
    end

    return 10
end

local function close_other_terminals(excluded_id)
    local _, terms = sorted_terminals()

    for _, term in ipairs(terms) do
        if term.id ~= excluded_id and term:is_open() and not term:is_float() then
            term:close()
        end
    end
end

function M.show(term, opts)
    opts = opts or {}
    local direction = opts.direction or term.direction or "horizontal"
    local size = opts.size or 10

    close_other_terminals(term.id)

    if term:is_open() and term.direction == direction then
        term:focus()
        return term
    end

    if term:is_open() then
        term:close()
    end

    term:open(size, direction)
    return term
end

local function show_existing(term, opts)
    opts = opts or {}
    local direction = opts.direction or term.direction or "horizontal"

    return M.show(term, {
        size = opts.size or default_size(term, direction),
        direction = direction,
    })
end

function M.new(opts)
    opts = opts or {}

    local terminal = terminal_module()
    local id = terminal.next_id()
    local direction = opts.direction or "horizontal"
    local term = terminal.Terminal:new({
        id = id,
        count = id,
        dir = opts.dir or project_root(),
        direction = direction,
        display_name = opts.display_name or ("Shell " .. id),
    })

    M.show(term, { size = opts.size or 10, direction = direction })
    return term
end

function M.toggle(id, opts)
    opts = opts or {}

    if id == nil or id == 0 then
        return M.toggle_shell(opts)
    end

    local terminal, terms = sorted_terminals()
    local term = terminal_by_id(terms, id)
    local direction = opts.direction or (term and term.direction) or "horizontal"

    if term == nil then
        term = terminal.Terminal:new({
            id = id,
            count = id,
            dir = opts.dir or project_root(),
            direction = direction,
            display_name = opts.display_name or ("Shell " .. id),
        })
    else
        term.dir = opts.dir or project_root()
    end

    if term:is_open() then
        term:close()
        return term
    end

    return show_existing(term, {
        size = opts.size,
        direction = direction,
    })
end

function M.toggle_shell(opts)
    opts = opts or {}

    local terminal = terminal_module()
    local direction = opts.direction or "horizontal"
    local size = opts.size or 10

    if shell_term == nil then
        local id = terminal.next_id()

        shell_term = terminal.Terminal:new({
            id = id,
            count = id,
            dir = project_root(),
            direction = direction,
            display_name = "Shell",
            on_exit = function()
                shell_term = nil
            end,
        })
    else
        shell_term.dir = project_root()
    end

    if shell_term:is_open() then
        shell_term:close()
        return shell_term
    end

    return M.show(shell_term, {
        size = size,
        direction = direction,
    })
end

function M.toggle_float()
    local terminal = terminal_module()

    if float_term == nil then
        float_term = terminal.Terminal:new({
            dir = project_root(),
            direction = "float",
            display_name = "Float shell",
            float_opts = { border = "rounded" },
        })
    else
        float_term.dir = project_root()
    end

    float_term:toggle()
    return float_term
end

local function open_cli(opts)
    local cmd = opts.cmd

    if vim.fn.executable(cmd) ~= 1 then
        vim.notify(("%s executable is not available in Neovim PATH"):format(cmd), vim.log.levels.ERROR)
        return nil
    end

    local terminal = terminal_module()
    local term = cli_terms[cmd]

    if term == nil then
        local id = terminal.next_id()

        term = terminal.Terminal:new({
            id = id,
            count = id,
            cmd = cmd,
            dir = project_root(),
            direction = "vertical",
            display_name = opts.display_name,
            on_exit = function()
                cli_terms[cmd] = nil
            end,
        })

        cli_terms[cmd] = term
    else
        term.dir = project_root()
    end

    return M.show(term, { size = vertical_size(0.4), direction = "vertical" })
end

function M.codex()
    return open_cli({
        cmd = "codex",
        display_name = "Codex",
    })
end

function M.claude()
    return open_cli({
        cmd = "claude",
        display_name = "Claude Code",
    })
end

function M.select()
    local _, terms = sorted_terminals()

    if #terms == 0 then
        M.new()
        return
    end

    vim.ui.select(terms, {
        prompt = "Select terminal",
        format_item = function(term)
            return terminal_label(term)
        end,
    }, function(choice)
        if choice == nil then
            return
        end

        show_existing(choice)
    end)
end

function M.toggle_all()
    vim.cmd("ToggleTermToggleAll")
end

function M.cycle(step)
    local terminal, terms = sorted_terminals()

    if #terms == 0 then
        M.new()
        return
    end

    local current_index = terminal_index(terms, terminal.get_focused_id())
        or terminal_index(terms, terminal.get_toggled_id())

    if current_index == nil then
        show_existing(terms[step > 0 and 1 or #terms])
        return
    end

    local target_index = ((current_index - 1 + step) % #terms) + 1

    show_existing(terms[target_index])
end

function M.next()
    M.cycle(1)
end

function M.previous()
    M.cycle(-1)
end

return M
