-- Shared motion language for Neovim, matching the Ghostty lock-on shaders:
-- things settle quickly into place, then four corner brackets home in on what
-- was acquired, flash, and fade. One accent color, one flash color.
local theme = require("core.theme")

local M = {}

function M.blend(from, to, t)
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local a = bit.band(bit.rshift(tonumber(from:sub(2), 16), shift), 0xff)
    local b = bit.band(bit.rshift(tonumber(to:sub(2), 16), shift), 0xff)
    out = out + bit.lshift(math.floor(a + (b - a) * t + 0.5), shift)
  end
  return ("#%06x"):format(out)
end

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

-- Lock-on timing: brackets accelerate in (homing), flash on contact, then fade.
local APPROACH_MS = 150
local HOLD_MS = 70
local FADE_MS = 230
local SPREAD_COLS = 4
local SPREAD_ROWS = 2

local CORNERS = {
  { text = "╭─", sy = -1, sx = -1 },
  { text = "─╮", sy = -1, sx = 1 },
  { text = "╰─", sy = 1, sx = -1 },
  { text = "─╯", sy = 1, sx = 1 },
}

local function apply_highlights()
  vim.api.nvim_set_hl(0, "MotionLock", { fg = M.accent, bold = true })
  vim.api.nvim_set_hl(0, "MotionLockFlash", { fg = M.flash, bold = true })
end
apply_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("MotionHighlights", { clear = true }),
  callback = apply_highlights,
})

local next_id = 0
local locks = {}

-- Corner position for one bracket, `spread` cells outside the final frame.
local function corner_pos(rect, corner, spread_rows, spread_cols)
  local top, left = rect.row - 1, rect.col - 1
  local bottom, right = rect.row + rect.height, rect.col + rect.width - 1
  local row = corner.sy < 0 and top - spread_rows or bottom + spread_rows
  local col = corner.sx < 0 and left - spread_cols or right + spread_cols
  row = math.max(0, math.min(vim.o.lines - 1, row))
  col = math.max(0, math.min(vim.o.columns - 2, col))
  return row, col
end

--- Lock brackets onto an editor-grid rectangle (0-based row/col of its content).
--- `opts.delay` postpones the approach so the lock lands when other motion settles;
--- `opts.spread` scales how far outside the target the brackets start;
--- `opts.on_lock` runs at the moment of contact.
function M.lock(rect, opts)
  opts = opts or {}
  if rect.width < 1 or rect.height < 1 then
    return
  end
  next_id = next_id + 1
  local id = "motion_lock_" .. next_id
  local delay = opts.delay or 0
  local reach = opts.spread or 1
  local wins, locked, fading = {}, false, false

  local function close()
    locks[id] = nil
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    wins = {}
  end
  locks[id] = close

  local function place(spread)
    local rows = math.floor(SPREAD_ROWS * reach * spread + 0.5)
    local cols = math.floor(SPREAD_COLS * reach * spread + 0.5)
    for i, corner in ipairs(CORNERS) do
      local row, col = corner_pos(rect, corner, rows, cols)
      local config = { relative = "editor", row = row, col = col, width = 2, height = 1 }
      if wins[i] and vim.api.nvim_win_is_valid(wins[i]) then
        vim.api.nvim_win_set_config(wins[i], config)
      else
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].bufhidden = "wipe"
        vim.b[buf].minianimate_disable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { corner.text })
        wins[i] = vim.api.nvim_open_win(buf, false, vim.tbl_extend("force", config, {
          style = "minimal",
          focusable = false,
          noautocmd = true,
          zindex = 250,
        }))
        vim.wo[wins[i]].winhighlight = "Normal:MotionLock"
      end
    end
  end

  local total = delay + APPROACH_MS + HOLD_MS + FADE_MS
  if delay == 0 then
    -- Show the brackets on this redraw instead of waiting for the first frame.
    place(1)
  end
  M.tween(id, { easing = "linear", duration = { total = total } }, function(progress, done)
    local t = progress * total - delay
    if t >= 0 then
      if t < APPROACH_MS then
        local k = t / APPROACH_MS
        place(1 - k * k)
      else
        if not locked then
          locked = true
          place(0)
          for _, win in ipairs(wins) do
            vim.wo[win].winhighlight = "Normal:MotionLockFlash"
          end
          if opts.on_lock then
            opts.on_lock()
          end
        end
        local fade = math.max(0, t - APPROACH_MS - HOLD_MS) / FADE_MS
        if fade > 0 then
          for _, win in ipairs(wins) do
            if vim.api.nvim_win_is_valid(win) then
              if not fading then
                vim.wo[win].winhighlight = "Normal:MotionLock"
              end
              vim.wo[win].winblend = math.floor(math.min(fade, 1) * 100)
            end
          end
          fading = true
        end
      end
    end
    if done then
      close()
    end
  end)
  return id
end

--- Drop a lock whose target went away before the brackets landed.
function M.unlock(id)
  if id and locks[id] then
    M.stop(id)
    locks[id]()
  end
end

--- Editor-grid bounding box of the visible part of buffer ranges in `win`;
--- each range is `{ row = 0-based, first = 1-based byte, last = 1-based byte }`.
function M.text_rect(win, ranges)
  local top, left, bottom, right
  for _, range in ipairs(ranges) do
    local a = vim.fn.screenpos(win, range.row + 1, range.first)
    local b = vim.fn.screenpos(win, range.row + 1, range.last)
    if a.row > 0 and b.row > 0 then
      top = math.min(top or a.row, a.row)
      bottom = math.max(bottom or b.row, b.row)
      left = math.min(left or a.col, a.col)
      right = math.max(right or b.endcol, b.endcol)
    end
  end
  if top then
    return { row = top - 1, col = left - 1, height = bottom - top + 1, width = right - left + 1 }
  end
end

--- Editor-grid rectangle of a window's text area; floats include their border.
function M.window_rect(win)
  local info = vim.fn.getwininfo(win)[1]
  local rect = { row = info.winrow - 1, col = info.wincol - 1, height = info.height + (info.winbar or 0), width = info.width }
  local config = vim.api.nvim_win_get_config(win)
  if config.relative ~= "" and config.border and config.border ~= "none" and config.border ~= "" then
    rect.row, rect.col, rect.height, rect.width = rect.row - 1, rect.col - 1, rect.height + 2, rect.width + 2
  end
  return rect
end

M.APPROACH_MS = APPROACH_MS

return M
