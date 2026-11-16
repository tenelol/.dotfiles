-- Colors from OmniWM App Theming. On the OmniWM rice a custom template
-- (modules/omniwm/files/app-themes/nvim-palette) renders OmniWM's palette, by
-- default the wallpaper's, into a plain `role=#rrggbb` file. This module turns
-- those roles into the keys of core.theme and reapplies them when the file
-- changes. Without the file, or on any other rice, Glacier stays as it is.
local M = {}

local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")

local function exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
  end
  return file ~= nil
end

-- modules/omniwm deploys the template on the OmniWM rice only, so a rendered
-- file left behind by an earlier rice is not picked up.
M.enabled = exists(config_home .. "/omniwm/app-themes/nvim-palette")
M.path = config_home .. "/theme/omniwm-palette"

local ROLES = {
  "background",
  "surface",
  "accentContainer",
  "foreground",
  "secondaryForeground",
  "mutedForeground",
  "ansi1",
  "ansi2",
  "ansi3",
  "ansi4",
  "ansi5",
  "ansi6",
  "ansi12",
  "base09",
}

local function blend(from, to, t)
  local out = "#"
  for i = 2, 6, 2 do
    local a, b = tonumber(from:sub(i, i + 1), 16), tonumber(to:sub(i, i + 1), 16)
    out = out .. ("%02x"):format(math.floor(a + (b - a) * t + 0.5))
  end
  return out
end

--- Roles in the rendered file, or nil unless every role core.theme needs is a
--- color. The file is read as data, never run.
function M.read(path)
  local file = io.open(path or M.path, "r")
  if not file then
    return nil
  end
  local roles = {}
  for line in file:lines() do
    local name, color = line:match("^(%w+)=(#%x%x%x%x%x%x)%s*$")
    if name then
      roles[name] = color:lower()
    end
  end
  file:close()
  for _, name in ipairs(ROLES) do
    if not roles[name] then
      return nil
    end
  end
  return roles
end

--- The core.theme keys for the rendered palette, or nil without one.
function M.colors(path)
  local p = M.enabled and M.read(path)
  if not p then
    return nil
  end
  return {
    bg = p.background,
    bg_dark = blend(p.background, "#000000", 0.3),
    bg_highlight = p.surface,
    bg_selection = p.accentContainer,
    -- OmniWM gives Ghostty this foreground; body text sits a step below it so
    -- function names still stand out.
    fg_bright = p.foreground,
    fg = blend(p.foreground, p.secondaryForeground, 0.5),
    fg_dark = p.secondaryForeground,
    -- mutedForeground is ANSI 8, which OmniWM keeps readable on the background.
    fg_gutter = blend(p.mutedForeground, p.background, 0.4),
    comment = p.mutedForeground,
    -- The accent stays ANSI blue, the color Ghostty's lock-on shaders draw with.
    blue = p.ansi4,
    blue0 = p.ansi12,
    cyan = p.ansi6,
    green = p.ansi2,
    yellow = p.ansi3,
    orange = p.base09,
    red = p.ansi1,
    magenta = p.ansi5,
    purple = blend(p.ansi4, p.foreground, 0.6),
    indent_scope = blend(p.ansi4, p.background, 0.3),
  }
end

--- Copy the rendered palette into core.theme and redraw. Plugin setups that
--- captured colors when they loaded (lualine, bufferline) follow on restart.
function M.apply()
  local colors = M.colors()
  if not colors then
    return
  end
  local theme = require("core.theme")
  local changed = false
  for key, value in pairs(colors) do
    if theme[key] ~= value then
      theme[key] = value
      changed = true
    end
  end
  local current = vim.g.colors_name
  if changed and current and current:match("^tokyonight") then
    vim.cmd.colorscheme(current)
  end
end

--- Reapply when OmniWM rewrites the file. It replaces the file in one step, so
--- the folder is watched, and anything changing in it leads to a cheap recheck.
function M.watch()
  local folder = vim.fs.dirname(M.path)
  if not M.enabled or M.watcher or not vim.uv.fs_stat(folder) then
    return
  end
  local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  if not watcher or not timer then
    return
  end
  local apply = vim.schedule_wrap(M.apply)
  local started = watcher:start(folder, {}, function(problem)
    if not problem then
      timer:stop()
      timer:start(200, 0, apply)
    end
  end)
  if started then
    M.watcher = watcher
  end
end

return M
