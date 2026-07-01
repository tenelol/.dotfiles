require("features.web")
require("features.platformio")

for _, path in ipairs({ vim.fn.stdpath("data"), vim.fn.stdpath("state"), vim.fn.stdpath("cache") }) do
  vim.fn.mkdir(path, "p")
end

local plugin_modules = require("nix-plugin-modules")
local specs = {}

local function is_enabled(spec)
  return type(spec) == "table" and spec.enabled ~= false
end

local function add_spec(spec)
  if not is_enabled(spec) then
    return
  end

  if type(spec.dependencies) == "table" then
    for _, dep in ipairs(spec.dependencies) do
      add_spec(dep)
    end
  end

  if spec.init or spec.config or spec.keys or spec.priority then
    table.insert(specs, {
      spec = spec,
      index = #specs + 1,
    })
  end
end

for _, module in ipairs(plugin_modules) do
  local ok, result = pcall(require, module)
  if ok and type(result) == "table" then
    for _, spec in ipairs(result) do
      add_spec(spec)
    end
  elseif not ok then
    vim.schedule(function()
      vim.notify(("nixvim plugin module failed: %s\n%s"):format(module, result), vim.log.levels.ERROR)
    end)
  end
end

table.sort(specs, function(left, right)
  local left_priority = left.spec.priority or 0
  local right_priority = right.spec.priority or 0
  if left_priority == right_priority then
    return left.index < right.index
  end
  return left_priority > right_priority
end)

local function spec_key(spec)
  return spec.name or spec[1] or spec.dir
end

local function spec_name(spec)
  return spec_key(spec) or "unknown"
end

local specs_by_key = {}
for _, entry in ipairs(specs) do
  local key = spec_key(entry.spec)
  if key then
    local current = specs_by_key[key]
    if not current or (type(entry.spec.config) == "function" and type(current.config) ~= "function") then
      specs_by_key[key] = entry.spec
    end
  end
end

local function canonical_spec(spec)
  local key = spec_key(spec)
  return (key and specs_by_key[key]) or spec
end

local configured = setmetatable({}, { __mode = "k" })
local configuring = setmetatable({}, { __mode = "k" })
local lazy_group = vim.api.nvim_create_augroup("NixvimPluginLazyConfig", { clear = true })

local function as_list(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    return value
  end
  return { value }
end

local function has_trigger(value)
  return #as_list(value) > 0
end

local function has_lazy_trigger(spec)
  return spec.lazy == true or has_trigger(spec.event) or has_trigger(spec.ft)
end

local function config_at_start(spec)
  if type(spec.config) ~= "function" and type(spec.dependencies) ~= "table" then
    return false
  end
  if spec.lazy == false then
    return true
  end
  return not has_lazy_trigger(spec)
end

local function run_hook(kind, spec)
  local hook = spec[kind]
  if type(hook) ~= "function" then
    return true
  end

  local ok, err = pcall(hook, spec, spec.opts or {})
  if not ok then
    vim.schedule(function()
      vim.notify(("nixvim plugin %s %s failed:\n%s"):format(spec_name(spec), kind, err), vim.log.levels.ERROR)
    end)
    return false
  end
  return true
end

local configure_spec

local function configure_dependencies(spec)
  if type(spec.dependencies) ~= "table" then
    return true
  end

  for _, dep in ipairs(spec.dependencies) do
    if is_enabled(dep) then
      local dependency = canonical_spec(dep)
      if dependency ~= spec and not configure_spec(dependency) then
        return false
      end
    end
  end

  return true
end

configure_spec = function(spec)
  spec = canonical_spec(spec)
  if configured[spec] then
    return true
  end
  if configuring[spec] then
    return false
  end

  configuring[spec] = true
  local ok = configure_dependencies(spec)
  if ok and type(spec.config) == "function" then
    ok = run_hook("config", spec)
  end
  configuring[spec] = nil
  if ok then
    configured[spec] = true
  end
  return ok
end

local function keymap_opts(mapping)
  local opts = {}
  for key, value in pairs(mapping) do
    if type(key) == "string" and key ~= "mode" then
      opts[key] = value
    end
  end
  return opts
end

local function feed_mapping(keys, mode)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, mode or "m", false)
end

local function apply_lazy_key(spec, mapping)
  local lhs = mapping[1]
  local rhs = mapping[2]
  local opts = keymap_opts(mapping)

  if rhs ~= nil then
    vim.keymap.set(mapping.mode or "n", lhs, function()
      local ok = configure_spec(spec)
      if not ok then
        return opts.expr and "" or nil
      end

      if type(rhs) == "function" then
        return rhs()
      end
      if opts.expr then
        return rhs
      end
      feed_mapping(rhs)
      return nil
    end, opts)
    return
  end

  local replaying = false
  vim.keymap.set(mapping.mode or "n", lhs, function()
    if replaying then
      return nil
    end

    local ok = configure_spec(spec)
    if not ok then
      return nil
    end

    replaying = true
    vim.schedule(function()
      feed_mapping(lhs)
      vim.defer_fn(function()
        replaying = false
      end, 20)
    end)
    return nil
  end, opts)
end

local function apply_keys(spec)
  if type(spec.keys) ~= "table" then
    return
  end

  for _, mapping in ipairs(spec.keys) do
    if type(mapping) == "table" and mapping[1] then
      if type(spec.config) == "function" and not config_at_start(spec) then
        apply_lazy_key(spec, mapping)
      elseif mapping[2] ~= nil then
        vim.keymap.set(mapping.mode or "n", mapping[1], mapping[2], keymap_opts(mapping))
      end
    end
  end
end

local function register_event_triggers(spec)
  if type(spec.config) ~= "function" or config_at_start(spec) then
    return
  end

  for _, event in ipairs(as_list(spec.event)) do
    if type(event) == "string" then
      if event == "VeryLazy" then
        vim.api.nvim_create_autocmd("User", {
          group = lazy_group,
          pattern = "VeryLazy",
          once = true,
          callback = function()
            configure_spec(spec)
          end,
        })
      else
        vim.api.nvim_create_autocmd(event, {
          group = lazy_group,
          once = true,
          callback = function()
            configure_spec(spec)
          end,
        })
      end
    end
  end
end

local function register_ft_triggers(spec)
  if type(spec.config) ~= "function" or config_at_start(spec) or not has_trigger(spec.ft) then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = lazy_group,
    pattern = as_list(spec.ft),
    once = true,
    callback = function()
      configure_spec(spec)
    end,
  })
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = lazy_group,
  once = true,
  callback = function()
    vim.schedule(function()
      vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
    end)
  end,
})

for _, entry in ipairs(specs) do
  run_hook("init", entry.spec)
end

for _, entry in ipairs(specs) do
  apply_keys(entry.spec)
end

for _, entry in ipairs(specs) do
  register_event_triggers(entry.spec)
  register_ft_triggers(entry.spec)
end

for _, entry in ipairs(specs) do
  if config_at_start(entry.spec) then
    configure_spec(entry.spec)
  end
end
