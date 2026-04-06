local project = require("core.project")

local M = {}

local float_term

local function project_root()
    return project.buffer_root(0)
end

local function terminal_module()
    return require("toggleterm.terminal")
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

local function focus_or_open(term)
    if term:is_open() then
        term:focus()
        return
    end

    term:open(10, term.direction)
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

    term:toggle(opts.size or 10, direction)
    return term
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

function M.select()
    vim.cmd("TermSelect")
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
        or 1
    local target_index = ((current_index - 1 + step) % #terms) + 1

    focus_or_open(terms[target_index])
end

function M.next()
    M.cycle(1)
end

function M.previous()
    M.cycle(-1)
end

return M
