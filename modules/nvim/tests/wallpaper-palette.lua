-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/wallpaper-palette.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")

local rendered = os.tmpname()
local function write(lines)
  local file = assert(io.open(rendered, "w"))
  file:write(table.concat(lines, "\n") .. "\n")
  file:close()
end

-- The roles the OmniWM template writes, in the file's own format.
local roles = {
  "# comment lines and mode are ignored",
  "mode=dark",
  "background=#101418",
  "surface=#1C2024",
  "accentContainer=#284777",
  "foreground=#e0e2e8",
  "secondaryForeground=#c2c7cf",
  "mutedForeground=#8c9199",
  "ansi1=#ffb4ab",
  "ansi2=#a8c8ff",
  "ansi3=#bcc7dc",
  "ansi4=#d9bde3",
  "ansi5=#c9dcff",
  "ansi6=#d5dff4",
  "ansi12=#e8d5f0",
  "base09=#dec4c4",
}

-- Other rices never read the file, even when one is left behind.
write(roles)
local palette = require("core.wallpaper-palette")
palette.path = rendered
palette.enabled = false
assert(palette.read() ~= nil and palette.colors() == nil, "A readable file should still be ignored while off")
palette.enabled = true

-- Without a rendered palette, Glacier is untouched.
os.remove(rendered)
assert(palette.colors() == nil, "A missing file should leave the static theme")
package.loaded["core.theme"] = nil
local theme = require("core.theme")
assert(theme.bg == "#0a0d12" and theme.blue == "#8ab4f8", "Glacier should be the default")
local glacier = {}
for key, value in pairs(theme) do
  glacier[key] = value
end

-- A rendered palette covers every Glacier key with a color.
write(roles)
local colors = assert(palette.colors(), "A complete palette should be read")
for key in pairs(glacier) do
  assert(type(colors[key]) == "string" and colors[key]:match("^#%x%x%x%x%x%x$"), "No color for " .. key)
end
for key in pairs(colors) do
  assert(glacier[key], "Palette sets a key the theme does not have: " .. key)
end
assert(colors.bg == "#101418" and colors.bg_highlight == "#1c2024", "Surfaces come from the palette, lowercased")
assert(colors.fg_bright == "#e0e2e8" and colors.fg_dark == "#c2c7cf", "Text follows the palette's foregrounds")
assert(colors.fg == "#d1d5dc", "Body text sits between the two foregrounds, got " .. colors.fg)
assert(colors.bg_dark == "#0b0e11", "The dark background is 30% toward black, got " .. colors.bg_dark)
assert(colors.blue == "#d9bde3" and colors.green == "#a8c8ff", "Syntax colors follow the terminal colors")
assert(colors.blue ~= colors.green, "Keywords and strings stay apart when the terminal follows the palette")

-- A new Neovim starts with the palette; a running one takes it in place.
package.loaded["core.theme"] = nil
assert(require("core.theme").bg == "#101418", "core.theme should start from the rendered palette")
package.loaded["core.theme"] = nil
os.remove(rendered)
theme = require("core.theme")
local motion_view = theme
write(roles)
palette.apply()
assert(motion_view.bg == "#101418" and motion_view.red == "#ffb4ab", "apply should update the shared theme table")

-- The colorscheme is redrawn once per change, and only while it is ours.
local redraws = 0
vim.cmd.colorscheme = function(name)
  assert(name == "tokyonight-storm", "Unexpected colorscheme " .. tostring(name))
  redraws = redraws + 1
end
vim.g.colors_name = "tokyonight-storm"
roles[9] = "ansi1=#ff897d"
write(roles)
palette.apply()
palette.apply()
assert(theme.red == "#ff897d" and redraws == 1, "A changed color should redraw once, got " .. redraws)
vim.g.colors_name = "habamax"
roles[9] = "ansi1=#ffb4ab"
write(roles)
palette.apply()
assert(theme.red == "#ffb4ab" and redraws == 1, "Another colorscheme should be left alone")

-- The OmniWM template renders every role this module needs.
local template = assert(io.open(vim.fn.getcwd() .. "/modules/omniwm/files/app-themes/nvim-palette", "r"))
local filled = template:read("*a"):gsub("{{mode}}", "dark"):gsub("{{colors%.[%w]+%.default%.hex}}", "#A1B2C3")
template:close()
assert(not filled:find("{{", 1, true), "The template has a placeholder this test does not know")
write({ filled })
assert(assert(palette.colors(), "The rendered template should be a complete palette").bg == "#a1b2c3")

-- An incomplete or malformed file is ignored as a whole.
local partial = {}
for _, line in ipairs(roles) do
  if not line:match("^ansi4=") then
    partial[#partial + 1] = line
  end
end
write(partial)
assert(palette.colors() == nil, "A palette missing a role should be ignored")
roles[3] = "background=os.execute('true')"
write(roles)
assert(palette.colors() == nil, "Only colors are accepted as values")
palette.apply()
assert(theme.bg == "#101418", "A bad file should leave the current colors")

os.remove(rendered)
print("wallpaper-palette: ok")
