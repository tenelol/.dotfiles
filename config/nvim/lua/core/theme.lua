local function hex_to_rgb(hex)
  return {
    tonumber(hex:sub(2, 3), 16),
    tonumber(hex:sub(4, 5), 16),
    tonumber(hex:sub(6, 7), 16),
  }
end

local function rgb_to_hex(rgb)
  return string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local function blend(fg, bg, alpha)
  local fg_rgb = hex_to_rgb(fg)
  local bg_rgb = hex_to_rgb(bg)
  local blended = {}

  for i = 1, 3 do
    blended[i] = math.floor((fg_rgb[i] * alpha) + (bg_rgb[i] * (1 - alpha)) + 0.5)
  end

  return rgb_to_hex(blended)
end

local theme = {
  bg = "#24283b",
  bg_dark = "#1f2335",
  bg_highlight = "#292e42",
  bg_selection = "#364a82",
  fg = "#e4e8ef",
  fg_dark = "#a4acb9",
  fg_gutter = "#535b6a",
  blue = "#77a8ff",
  blue0 = "#536f9f",
  comment = "#707989",
  cyan = "#80c8e8",
  green = "#82c7d2",
  magenta = "#b7a6d9",
  orange = "#9db9d7",
  purple = "#a9b5d7",
  red = "#c7a0f7",
  yellow = "#8ecfc8",
}

theme.ibl_indent = blend(theme.fg_gutter, theme.bg, 0.35)
theme.ibl_scope = blend(theme.blue, theme.bg, 0.5)

return theme
