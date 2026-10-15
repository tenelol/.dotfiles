-- Yank sweep: a bright head runs through the yanked text in reading order and
-- leaves a trail that cools from the accent color back into the background.
local theme = require("core.theme")

local M = {}

local ns = vim.api.nvim_create_namespace("dotfiles_yank_sweep")
local FRAME_MS = 16
local SWEEP_MS = 140
local COOL_MS = 300
-- Large yanks are grouped so a frame never draws more than this many marks.
local MAX_BUCKETS = 96
local LEVELS = 8

local active

local function blend(from, to, t)
  local function channel(hex, shift)
    return bit.band(bit.rshift(tonumber(hex:sub(2), 16), shift), 0xff)
  end
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local a, b = channel(from, shift), channel(to, shift)
    out = out + bit.lshift(math.floor(a + (b - a) * t + 0.5), shift)
  end
  return ("#%06x"):format(out)
end

-- Level 1 is the white-hot head; higher levels cool through the accent into
-- the selection color and then the background.
local function apply_highlights()
  local head = blend(theme.blue, theme.fg_bright, 0.55)
  for level = 1, LEVELS do
    local t = (level - 1) / (LEVELS - 1)
    local color = t < 0.4 and blend(head, theme.magenta, t / 0.4)
      or blend(blend(theme.magenta, theme.bg_selection, 0.35), theme.bg_highlight, (t - 0.4) / 0.6)
    vim.api.nvim_set_hl(0, "YankSweep" .. level, { bg = color })
  end
end

local function stop()
  if not active then
    return
  end
  active.timer:stop()
  active.timer:close()
  if vim.api.nvim_buf_is_valid(active.buf) then
    vim.api.nvim_buf_clear_namespace(active.buf, ns, 0, -1)
  end
  active = nil
end

-- Character cells of the yanked region, in reading order, as byte ranges.
local function region_cells(buf, regtype)
  local start = vim.api.nvim_buf_get_mark(buf, "[")
  local finish = vim.api.nvim_buf_get_mark(buf, "]")
  if start[1] == 0 or finish[1] == 0 then
    return {}
  end
  -- Linewise marks put "]" at MAXCOL, which overflows getregionpos once made 1-based.
  local last_line = vim.api.nvim_buf_get_lines(buf, finish[1] - 1, finish[1], false)[1] or ""
  local regions = vim.fn.getregionpos(
    { buf, start[1], start[2] + 1, 0 },
    { buf, finish[1], math.min(finish[2], math.max(#last_line - 1, 0)) + 1, 0 },
    { type = regtype, exclusive = false }
  )
  local cells = {}
  for _, range in ipairs(regions) do
    local row, first, last = range[1][2] - 1, range[1][3], range[2][3]
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    last = math.min(last, #line)
    if first <= last then
      local chunk = line:sub(first, last)
      local starts = vim.str_utf_pos(chunk)
      for i, offset in ipairs(starts) do
        local next_offset = starts[i + 1] or (#chunk + 1)
        cells[#cells + 1] = { row, first - 1 + offset - 1, first - 1 + next_offset - 1 }
      end
    end
  end
  return cells
end

local function bucketize(cells, blockwise)
  local size = math.max(1, math.ceil(#cells / MAX_BUCKETS))
  local buckets = {}
  for i = 1, #cells, size do
    local group = {}
    for j = i, math.min(i + size - 1, #cells) do
      local cell = cells[j]
      local last = group[#group]
      -- Charwise and linewise regions are contiguous, so one mark may span
      -- rows; block columns only merge within a row.
      if last and (not blockwise or (last[3] == cell[1] and last[4] == cell[2])) then
        last[3], last[4] = cell[1], cell[3]
      else
        group[#group + 1] = { cell[1], cell[2], cell[1], cell[3] }
      end
    end
    buckets[#buckets + 1] = group
  end
  return buckets
end

local function draw(state, elapsed)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  local count = #state.buckets
  local head = count * math.min(elapsed / SWEEP_MS, 1)
  local finished = true
  for index, group in ipairs(state.buckets) do
    -- Time since the head passed this bucket.
    local age = elapsed - (index - 1) / count * SWEEP_MS
    if head >= index - 1 and age < COOL_MS then
      finished = false
      local level = math.min(LEVELS, 1 + math.floor(age / COOL_MS * LEVELS))
      for _, mark in ipairs(group) do
        vim.api.nvim_buf_set_extmark(state.buf, ns, mark[1], mark[2], {
          end_row = mark[3],
          end_col = mark[4],
          hl_group = "YankSweep" .. level,
          priority = 250,
          strict = false,
        })
      end
    elseif head < index - 1 then
      finished = false
    end
  end
  return finished
end

function M.play(buf, regtype)
  stop()
  local cells = region_cells(buf, regtype)
  if #cells == 0 then
    return
  end
  local state = { buf = buf, buckets = bucketize(cells, regtype == "\22"), start = vim.uv.hrtime(), timer = vim.uv.new_timer() }
  active = state
  state.timer:start(
    0,
    FRAME_MS,
    vim.schedule_wrap(function()
      if active ~= state then
        return
      end
      if not vim.api.nvim_buf_is_valid(buf) or draw(state, (vim.uv.hrtime() - state.start) / 1e6) then
        stop()
      end
    end)
  )
end

function M.setup()
  apply_highlights()
  local group = vim.api.nvim_create_augroup("YankSweep", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = apply_highlights })
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function(event)
      if vim.v.event.operator == "y" then
        -- Blockwise regtype carries the width ("\22{width}"); getregionpos wants the bare type.
        M.play(event.buf, vim.v.event.regtype:sub(1, 1))
      end
    end,
  })
end

return M
