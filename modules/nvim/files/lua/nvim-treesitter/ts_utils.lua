local M = {}

function M.get_node_at_cursor()
    if vim.treesitter.get_node ~= nil then
        return vim.treesitter.get_node()
    end

    return nil
end

return M
