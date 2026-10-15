-- Light-bar reveal for side panels. The panel opens at its final size at once,
-- so its content never re-lays out per frame; a floating overlay hides the
-- part not yet shown and a one-cell bar of light sweeps across it. The bar's
-- edges use eighth-block glyphs, so it moves in 1/8-cell steps instead of
-- jumping whole cells.
local theme = require("core.theme")

local M = {}

local ns = vim.api.nvim_create_namespace("dotfiles_panel_reveal")
local FRAME_MS = 8
local TRAIL_CELLS = 5
local LEVELS = 10

-- Fill glyphs indexed by eighths (1-7), keyed by the side of the cell they fill.
local FILL = {
  left = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" },
  right = { "▕", "🮇", "🮈", "▐", "🮉", "🮊", "🮋" },
  bottom = { "▁", "▂", "▃", "▄", "▅", "▆", "▇" },
  top = { "▔", "🮂", "🮃", "▀", "🮄", "🮅", "🮆" },
}
local OPPOSITE = { left = "right", right = "left", top = "bottom", bottom = "top" }

local active = {}

local function blend(from, to, t)
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    local a = bit.band(bit.rshift(tonumber(from:sub(2), 16), shift), 0xff)
    local b = bit.band(bit.rshift(tonumber(to:sub(2), 16), shift), 0xff)
    out = out + bit.lshift(math.floor(a + (b - a) * t + 0.5), shift)
  end
  return ("#%06x"):format(out)
end

local function trail_color(level)
  local t = level / LEVELS
  return t < 0.45 and blend(theme.blue, theme.magenta, t / 0.45)
    or blend(theme.magenta, theme.bg, (t - 0.45) / 0.55)
end

local function apply_highlights()
  local bar = blend(theme.blue, theme.fg_bright, 0.5)
  vim.api.nvim_set_hl(0, "PanelRevealBar", { bg = bar })
  -- Split cells: bar glyph over the curtain or over a trail level.
  vim.api.nvim_set_hl(0, "PanelRevealEdge0", { fg = bar })
  for level = 1, LEVELS do
    vim.api.nvim_set_hl(0, "PanelRevealTrail" .. level, { bg = trail_color(level) })
    vim.api.nvim_set_hl(0, "PanelRevealEdge" .. level, { fg = bar, bg = trail_color(level) })
  end
end

local function ease_out_quart(t)
  return 1 - (1 - t) ^ 4
end

-- Screen rectangle of the window, including its border when it floats.
local function rect(win)
  local info = vim.fn.getwininfo(win)[1]
  local row, col = info.winrow - 1, info.wincol - 1
  local height, width = info.height + (info.winbar or 0), info.width
  local config = vim.api.nvim_win_get_config(win)
  if config.relative ~= "" and config.border and config.border ~= "none" and config.border ~= "" then
    row, col, height, width = row - 1, col - 1, height + 2, width + 2
  end
  return row, col, height, width
end

-- Past the trail's end a closing sweep shows plain curtain; an opening sweep
-- keeps its faintest level, because those cells only exist to finish the trail.
local function trail_level(distance, length, open)
  if length <= 0 or (not open and distance > length) then
    return nil
  end
  return math.min(LEVELS, math.max(1, math.ceil(distance / length * LEVELS)))
end

-- What to draw in each along-axis cell. Cells are counted from the anchor edge;
-- the curtain covers [boundary, length) and the bar plus its trail sit behind the
-- boundary in the direction of travel.
local function cells(state, boundary, trail)
  local length, sign = state.length, state.sign
  local near, far = state.edge, OPPOSITE[state.edge]
  -- Snap to the glyph resolution so a split cell always holds 1-7 eighths.
  boundary = math.floor(boundary * 8 + 0.5) / 8
  local eighths = math.floor((boundary - math.floor(boundary)) * 8 + 0.5)
  local first = sign > 0 and math.max(0, math.floor(boundary - 1 - trail)) or math.max(0, math.floor(boundary))
  local out = {}
  for j = first, length - 1 do
    local glyph, hl = " ", nil
    if sign > 0 then
      -- Opening: content | trail | bar | curtain.
      local bar_start = boundary - 1
      if j == math.floor(boundary) then
        if eighths > 0 then
          glyph, hl = FILL[near][eighths], "PanelRevealEdge0"
        end
      elseif j == math.floor(bar_start) and j >= 0 then
        local level = trail_level(1, trail, true)
        if eighths == 0 then
          hl = "PanelRevealBar"
        else
          glyph, hl = FILL[far][8 - eighths], level and ("PanelRevealEdge" .. level) or "PanelRevealEdge0"
        end
      elseif j < bar_start then
        local level = trail_level(bar_start - (j + 0.5), trail, true)
        hl = level and ("PanelRevealTrail" .. level) or nil
      end
    else
      -- Closing: content | bar | trail | curtain, with the bar moving to the anchor.
      local bar_end = boundary + 1
      if j == math.floor(boundary) then
        if eighths == 0 then
          hl = "PanelRevealBar"
        else
          glyph, hl = FILL[far][8 - eighths], "PanelRevealEdge0"
        end
      elseif j == math.floor(bar_end) then
        local level = trail_level(1, trail)
        if eighths > 0 then
          glyph, hl = FILL[near][eighths], level and ("PanelRevealEdge" .. level) or "PanelRevealEdge0"
        else
          hl = level and ("PanelRevealTrail" .. level) or nil
        end
      elseif j > bar_end then
        local level = trail_level(j + 0.5 - bar_end, trail)
        hl = level and ("PanelRevealTrail" .. level) or nil
      end
    end
    out[#out + 1] = { j = j, glyph = glyph, hl = hl }
  end
  return out
end

local function draw(state, progress)
  local boundary = state.sign > 0 and progress * state.length or (1 - progress) * state.length
  -- The trail is motion blur: long while fast, gone once the bar settles.
  local trail = TRAIL_CELLS * math.sqrt(1 - progress)
  local list = cells(state, boundary, trail)
  if #list == 0 then
    return false
  end

  local row, col, height, width = state.row, state.col, state.height, state.width
  local horizontal = state.edge == "left" or state.edge == "right"
  local count = #list
  -- Along-axis cell j sits at this screen offset from the panel's top-left.
  local function offset(j)
    return (state.edge == "left" or state.edge == "top") and j or (state.length - 1 - j)
  end
  local lo, hi = offset(list[1].j), offset(list[count].j)
  if lo > hi then
    lo, hi = hi, lo
  end
  local float = horizontal
      and { row = row, col = col + lo, width = hi - lo + 1, height = height }
    or { row = row + lo, col = col, width = width, height = hi - lo + 1 }

  local lines, marks = {}, {}
  if horizontal then
    local chunks = {}
    for k = 1, count do
      -- Screen order runs left to right; reverse when anchored on the right.
      local cell = state.edge == "left" and list[k] or list[count - k + 1]
      chunks[#chunks + 1] = { cell.glyph, cell.hl or "PanelRevealCurtain" }
    end
    local blank = (" "):rep(float.width)
    for r = 1, float.height do
      lines[r] = blank
      marks[r] = chunks
    end
  else
    local blank = (" "):rep(float.width)
    for k = 1, count do
      local cell = state.edge == "top" and list[k] or list[count - k + 1]
      lines[k] = blank
      if cell.hl then
        marks[k] = { { cell.glyph:rep(float.width), cell.hl } }
      end
    end
  end

  local config = {
    relative = "editor",
    row = float.row,
    col = float.col,
    width = float.width,
    height = float.height,
  }
  if state.overlay and vim.api.nvim_win_is_valid(state.overlay) then
    vim.api.nvim_win_set_config(state.overlay, config)
  else
    state.overlay = vim.api.nvim_open_win(
      state.buf,
      false,
      vim.tbl_extend("force", config, {
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = state.zindex,
      })
    )
    vim.wo[state.overlay].winhighlight = "Normal:PanelRevealCurtain,NormalFloat:PanelRevealCurtain"
    vim.wo[state.overlay].winblend = 0
  end
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for r, chunks in pairs(marks) do
    vim.api.nvim_buf_set_extmark(state.buf, ns, r - 1, 0, { virt_text = chunks, virt_text_pos = "overlay" })
  end
  return true
end

local function finish(win, completed)
  local state = active[win]
  if not state then
    return
  end
  active[win] = nil
  state.timer:stop()
  state.timer:close()
  if state.overlay and vim.api.nvim_win_is_valid(state.overlay) then
    vim.api.nvim_win_close(state.overlay, true)
  end
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  if vim.api.nvim_win_is_valid(win) then
    vim.w[win].dotfiles_panel_animation = nil
  end
  if state.on_done then
    state.on_done(completed)
  end
end

--- Sweep a panel open (`mode = "open"`) or shut (`mode = "close"`).
--- `edge` is the screen edge the panel is anchored to. `on_done(completed)` runs
--- once the sweep ends; `completed` is false when it was cancelled.
function M.play(win, opts)
  M.cancel(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local edge = opts.edge
  local row, col, height, width = rect(win)
  local horizontal = edge == "left" or edge == "right"
  local config = vim.api.nvim_win_get_config(win)
  local state = {
    edge = edge,
    sign = opts.mode == "close" and -1 or 1,
    row = row,
    col = col,
    height = height,
    width = width,
    length = horizontal and width or height,
    zindex = (config.zindex or 40) + 10,
    buf = vim.api.nvim_create_buf(false, true),
    timer = vim.uv.new_timer(),
    start = vim.uv.hrtime(),
    duration = opts.duration or (opts.mode == "close" and 220 or 320),
    on_done = opts.on_done,
  }
  vim.bo[state.buf].bufhidden = "wipe"
  -- Keep MiniAnimate from wiping the overlay itself when it closes.
  vim.b[state.buf].minianimate_disable = true
  active[win] = state
  vim.w[win].dotfiles_panel_animation = true
  draw(state, 0)
  state.timer:start(
    FRAME_MS,
    FRAME_MS,
    vim.schedule_wrap(function()
      if active[win] ~= state then
        return
      end
      if not vim.api.nvim_win_is_valid(win) then
        finish(win, false)
        return
      end
      local t = math.min(1, (vim.uv.hrtime() - state.start) / 1e6 / state.duration)
      if t >= 1 then
        finish(win, true)
      else
        draw(state, ease_out_quart(t))
      end
    end)
  )
end

function M.cancel(win)
  if active[win] then
    local on_done = active[win].on_done
    active[win].on_done = nil
    finish(win, false)
    if on_done then
      on_done(false)
    end
  end
end

function M.is_active(win)
  if win then
    return active[win] ~= nil
  end
  return next(active) ~= nil
end

function M.mode(win)
  return active[win] and (active[win].sign > 0 and "open" or "close") or nil
end

local function apply_curtain()
  -- The curtain shows the editor background, which may be transparent.
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  vim.api.nvim_set_hl(0, "PanelRevealCurtain", { bg = normal.bg })
end

apply_highlights()
apply_curtain()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("PanelReveal", { clear = true }),
  callback = function()
    apply_highlights()
    apply_curtain()
  end,
})

return M
