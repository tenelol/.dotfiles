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
  fg = "#d8e2ef",
  fg_dark = "#9eacc0",
  fg_gutter = "#565f89",
  blue = "#7aa2f7",
  blue0 = "#3d59a1",
  comment = "#65758b",
  cyan = "#7dcfff",
  green = "#72d5e8",
  magenta = "#a9bdf5",
  orange = "#8fb8f2",
  purple = "#9fafe5",
  red = "#82aaff",
  yellow = "#a7c7ff",
}

theme.ibl_indent = blend(theme.fg_gutter, theme.bg, 0.35)
theme.ibl_scope = blend(theme.blue, theme.bg, 0.5)

return theme
