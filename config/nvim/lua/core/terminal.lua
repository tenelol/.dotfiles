local project = require("core.project")

local M = {}

local float_term
local codex_term

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

function M.codex()
    if vim.fn.executable("codex") ~= 1 then
        vim.notify("codex executable is not available in Neovim PATH", vim.log.levels.ERROR)
        return nil
    end

    local terminal = terminal_module()

    if codex_term == nil then
        local id = terminal.next_id()

        codex_term = terminal.Terminal:new({
            id = id,
            count = id,
            cmd = "codex",
            dir = project_root(),
            direction = "vertical",
            display_name = "Codex",
            on_exit = function()
                codex_term = nil
            end,
        })
    else
        codex_term.dir = project_root()
    end

    return M.show(codex_term, { size = vertical_size(0.4), direction = "vertical" })
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
            return term.display_name or ("Terminal " .. term.id)
        end,
    }, function(choice)
        if choice == nil then
            return
        end

        M.show(choice, { size = 10, direction = "horizontal" })
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
        or 1
    local target_index = ((current_index - 1 + step) % #terms) + 1

    M.show(terms[target_index], { size = 10, direction = "horizontal" })
end

function M.next()
    M.cycle(1)
end

function M.previous()
    M.cycle(-1)
end

return M
