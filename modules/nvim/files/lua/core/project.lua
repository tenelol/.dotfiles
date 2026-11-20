local M = {}

local markers = {
    ".git",
    "flake.nix",
    "platformio.ini",
    "package.json",
    "pyproject.toml",
    "go.mod",
    "Cargo.toml",
}

local uv = vim.uv or vim.loop

local function normalize(path)
    return path and vim.fs.normalize(path) or nil
end

local function stat(path)
    local normalized = normalize(path)
    if normalized == nil or normalized == "" then
        return nil
    end

    return uv.fs_stat(normalized)
end

local function start_dir(path)
    local normalized = normalize(path)
    if normalized == nil or normalized == "" then
        return normalize(vim.fn.getcwd())
    end

    local path_stat = stat(normalized)
    if path_stat ~= nil and path_stat.type == "directory" then
        return normalized
    end

    return normalize(vim.fs.dirname(normalized))
end

function M.root(path)
    local start = start_dir(path)
    local found = vim.fs.find(markers, {
        path = start,
        upward = true,
    })[1]

    if found ~= nil then
        return normalize(vim.fs.dirname(found))
    end

    return start
end

function M.exists(path)
    return stat(path) ~= nil
end

function M.buffer_path(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr or 0)
    if name == "" then
        return nil
    end

    return normalize(name)
end

-- M.root falls back to the cwd for buffers without a name.
function M.buffer_root(bufnr)
    return M.root(M.buffer_path(bufnr))
end

return M
