local plugin_paths = dofile(vim.fn.stdpath("config") .. "/nix-managed-plugins.lua")

local M = {}

local function plugin_dir(attr)
  local dir = plugin_paths[attr]
  assert(dir, ("Missing Nix-managed plugin path for %s"):format(attr))
  return dir
end

function M.spec(attr, opts)
  return vim.tbl_deep_extend("force", {
    dir = plugin_dir(attr),
    name = attr,
  }, opts or {})
end

function M.dep(attr, opts)
  return M.spec(attr, opts)
end

return M
