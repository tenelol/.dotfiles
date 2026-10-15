-- Yank lock-on: brackets home in on the yanked text, and at contact the text
-- flashes and cools through the accent back into the background, the same beat
-- as the Ghostty jump reticle.
local motion = require("core.motion")
local theme = require("core.theme")

local M = {}

local ns = vim.api.nvim_create_namespace("dotfiles_yank_lock")
local COOL_MS = 320
local LEVELS = 8

local active

-- Level 1 is the flash; higher levels cool through the accent toward the
-- background. The last level doubles as the faint tint shown while aiming.
local function apply_highlights()
  for level = 1, LEVELS do
    local t = (level - 1) / (LEVELS - 1)
    local color = t < 0.3 and motion.blend(motion.flash, motion.accent, t / 0.3)
      or motion.blend(motion.accent, theme.bg_highlight, (t - 0.3) / 0.7)
    vim.api.nvim_set_hl(0, "YankLock" .. level, { bg = color })
  end
end

-- Byte ranges of the yanked region, one per line, from getregionpos.
local function region(buf, regtype)
  local start = vim.api.nvim_buf_get_mark(buf, "[")
  local finish = vim.api.nvim_buf_get_mark(buf, "]")
  if start[1] == 0 or finish[1] == 0 then
    return {}
  end
  -- Linewise marks put "]" at MAXCOL, which overflows getregionpos once made 1-based.
  local last_line = vim.api.nvim_buf_get_lines(buf, finish[1] - 1, finish[1], false)[1] or ""
  local ranges = {}
  for _, range in ipairs(vim.fn.getregionpos(
    { buf, start[1], start[2] + 1, 0 },
    { buf, finish[1], math.min(finish[2], math.max(#last_line - 1, 0)) + 1, 0 },
    { type = regtype, exclusive = false }
  )) do
    local row = range[1][2] - 1
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    local last = math.min(range[2][3], #line)
    if range[1][3] <= last then
      ranges[#ranges + 1] = { row = row, first = range[1][3], last = last }
    end
  end
  return ranges
end

-- Editor-grid bounding box of the visible part of the region.
local function screen_rect(win, ranges)
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

local function paint(state, level)
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  if not level then
    return
  end
  local hl = "YankLock" .. level
  local function mark(row, col, end_row, end_col)
    vim.api.nvim_buf_set_extmark(state.buf, ns, row, col, {
      end_row = end_row,
      end_col = end_col,
      hl_group = hl,
      priority = 250,
      strict = false,
    })
  end
  local ranges = state.ranges
  if state.blockwise then
    for _, range in ipairs(ranges) do
      mark(range.row, range.first - 1, range.row, range.last)
    end
  else
    -- Charwise and linewise regions are contiguous, so one mark covers them.
    mark(ranges[1].row, ranges[1].first - 1, ranges[#ranges].row, ranges[#ranges].last)
  end
end

local function stop()
  if active then
    motion.stop(active.id)
    paint(active, nil)
    active = nil
  end
end

function M.play(buf, regtype)
  stop()
  local ranges = region(buf, regtype)
  if #ranges == 0 then
    return
  end
  local state = { id = "yank_lock_" .. buf, buf = buf, ranges = ranges, blockwise = regtype == "\22" }
  active = state

  local function cool()
    motion.tween(state.id, { easing = "outQuad", duration = { total = COOL_MS } }, function(progress, done)
      if active ~= state then
        return
      end
      if done then
        stop()
      else
        paint(state, math.min(LEVELS, 1 + math.floor(progress * LEVELS)))
      end
    end)
  end

  local rect = screen_rect(vim.api.nvim_get_current_win(), ranges)
  if not rect then
    paint(state, 1)
    cool()
    return
  end
  paint(state, LEVELS)
  motion.lock(rect, {
    on_lock = function()
      if active == state then
        paint(state, 1)
        cool()
      end
    end,
  })
end

function M.setup()
  apply_highlights()
  local group = vim.api.nvim_create_augroup("YankLock", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_highlights })
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function(event)
      if vim.v.event.operator == "y" then
        -- Blockwise regtype carries the width ("\22{width}"); getregionpos wants the bare type.
        local regtype = vim.v.event.regtype:sub(1, 1)
        -- TextYankPost holds textlock, which forbids opening the bracket windows.
        vim.schedule(function()
          M.play(event.buf, regtype)
        end)
      end
    end,
  })
end

return M
