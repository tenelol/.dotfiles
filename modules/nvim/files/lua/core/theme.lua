-- Glacier: crisp monochrome with one ice-blue accent. The accent matches ANSI
-- blue in the Ghostty palette, which the lock-on shaders draw with.
local theme = {
  bg = "#0a0d12",
  bg_dark = "#07090d",
  bg_highlight = "#131a24",
  bg_selection = "#1d2a3d",
  fg_bright = "#eef3fa",
  fg = "#c9d4e3",
  fg_dark = "#8a96a8",
  fg_gutter = "#475262",
  comment = "#5f6b7b",
  -- Accent: keywords, borders, focus.
  blue = "#8ab4f8",
  -- Types, attributes, file icons.
  blue0 = "#a8c7fa",
  -- Builtins, tags, info.
  cyan = "#8fd3e8",
  -- Strings and additions.
  green = "#93d3c9",
  -- Numbers, constants and warnings.
  yellow = "#f2c37b",
  orange = "#f6ad7b",
  red = "#f28b82",
  magenta = "#c6a8f8",
  purple = "#b7c5dc",
}

theme.indent_scope = "#6f8fbf"

return theme
