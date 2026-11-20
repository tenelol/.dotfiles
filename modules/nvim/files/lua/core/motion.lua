-- Shared motion language for Neovim: things settle quickly into place with one
-- easing, and highlights flash and cool through one accent color.
local theme = require("core.theme")

local M = {}

M.blend = require("core.wallpaper-palette").blend

M.accent = theme.blue
M.flash = M.blend(theme.blue, theme.fg_bright, 0.7)

-- snacks.animate options shared by every panel and popup.
M.open = { easing = "outQuart", duration = { total = 240 } }
M.close = { easing = "inQuad", duration = { total = 170 } }

local RESOLUTION = 1000

--- Run `fn(progress, done)` with eased progress from 0 to 1. snacks.animate
--- spaces its frames by the value range (a 9 -> 10 resize would take one step
--- per 240 ms), so animate a fixed range and let callers map it.
function M.tween(id, preset, fn)
  require("snacks").animate(0, RESOLUTION, function(value, ctx)
    fn(value / RESOLUTION, ctx.done)
  end, { id = id, easing = preset.easing, duration = preset.duration })
end

function M.stop(id)
  require("snacks").animate.del(id)
end

return M
