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
  bg = "#171b23",
  bg_dark = "#11151d",
  bg_highlight = "#202631",
  bg_selection = "#293448",
  fg_bright = "#d8dde6",
  fg = "#b3bbc7",
  fg_dark = "#8993a3",
  fg_gutter = "#4f5968",
  blue = "#7f9bc4",
  blue0 = "#5f7695",
  comment = "#626c7a",
  -- Keep former cyan accents aligned with the muted file-icon blue.
  cyan = "#5f7695",
  green = "#88c0b8",
  magenta = "#a894c7",
  orange = "#8fa6bd",
  purple = "#a8b4ce",
  red = "#c4a0e8",
  yellow = "#94b8c7",
}

theme.ibl_indent = blend(theme.fg_gutter, theme.bg, 0.35)
theme.ibl_scope = blend(theme.blue, theme.bg, 0.5)

return theme
