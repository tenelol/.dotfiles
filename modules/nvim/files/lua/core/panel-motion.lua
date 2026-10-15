-- Panels grow and shrink along one axis with the shared easing, then the
-- lock-on brackets land on them. Nothing underneath re-lays out per frame:
-- Edgy is held off, and a terminal's pty is pinned to its final size by a
-- hidden float showing the same buffer (Neovim sizes a pty to the largest
-- window displaying it), so the shell never re-flows mid-animation.
local motion = require("core.motion")

local M = {}
local active = {}

local function size_of(win, axis)
  return vim.api["nvim_win_get_" .. axis](win)
end

local function release(win)
  local state = active[win]
  if not state then
    return
  end
  active[win] = nil
  motion.stop(state.id)
  if state.pin and vim.api.nvim_win_is_valid(state.pin) then
    vim.api.nvim_win_close(state.pin, true)
  end
  if vim.api.nvim_win_is_valid(win) then
    vim.w[win].edgy_disable = state.edgy_disable
    vim.w[win].dotfiles_panel_animation = nil
    if state.wrap ~= nil then
      vim.wo[win].wrap = state.wrap
    end
    if state.restore then
      state.restore()
    end
  end
  return state
end

local function pin_terminal(win, width, height)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "terminal" then
    return nil
  end
  return vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = width,
    height = height,
    hide = true,
    focusable = false,
    noautocmd = true,
    style = "minimal",
  })
end

-- Where the window will sit once it reaches `size`: a panel anchored to the far
-- edge moves its origin as it grows, which shows up between two samples.
local function final_rect(first, now, axis, size)
  local rect = vim.deepcopy(now)
  if axis == "width" then
    if now.col ~= first.col then
      rect.col = now.col + now.width - size
    end
    rect.width = size
  else
    if now.row ~= first.row then
      rect.row = now.row + now.height - size
    end
    rect.height = size
  end
  return rect
end

local function animate(win, opts)
  local previous = release(win)
  if previous then
    motion.unlock(previous.lock)
    if previous.on_done then
      previous.on_done(false)
    end
  end
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local axis, opening = opts.axis, opts.mode == "open"
  local from = opts.from or size_of(win, axis)
  local to = opening and opts.size or 1
  local preset = opening and motion.open or motion.close
  local state = {
    id = "panel_motion_" .. win,
    mode = opts.mode,
    on_done = opts.on_done,
    edgy_disable = vim.w[win].edgy_disable,
  }
  active[win] = state
  vim.w[win].edgy_disable = true
  vim.w[win].dotfiles_panel_animation = true

  local full = math.max(from, to)
  local width = axis == "width" and full or vim.api.nvim_win_get_width(win)
  local height = axis == "height" and full or vim.api.nvim_win_get_height(win)
  state.pin = pin_terminal(win, width, height)
  if state.pin and axis == "width" then
    -- The pinned pty is wider than the window mid-animation; clip instead of wrapping.
    state.wrap = vim.wo[win].wrap
    vim.wo[win].wrap = false
  end

  vim.api["nvim_win_set_" .. axis](win, from)
  local first = motion.window_rect(win)
  local start = vim.uv.hrtime()
  local duration = preset.duration.total
  local locking = not (opening and opts.lock)

  motion.tween(state.id, preset, function(progress, done)
    if active[win] ~= state then
      return
    end
    if not vim.api.nvim_win_is_valid(win) then
      release(win)
      return
    end
    vim.api["nvim_win_set_" .. axis](win, math.floor(from + (to - from) * progress + 0.5))
    -- Launch the brackets early enough that they land as the panel settles.
    if not locking and (vim.uv.hrtime() - start) / 1e6 >= duration - motion.APPROACH_MS then
      locking = true
      state.lock = motion.lock(final_rect(first, motion.window_rect(win), axis, to))
    end
    if done then
      release(win)
      -- Let Edgy adopt the settled window again.
      pcall(vim.api.nvim_exec_autocmds, "WinResized", {})
      if state.on_done then
        state.on_done(true)
      end
    end
  end)
end

--- Grow `win` along `axis` ("width" or "height") to `size`, then call
--- `on_done(completed)` if given. Reversing a close continues from the current size.
function M.open(win, opts)
  local continuing = active[win] and active[win].mode == "close"
  animate(win, {
    axis = opts.axis,
    size = opts.size,
    mode = "open",
    from = continuing and size_of(win, opts.axis) or 1,
    lock = opts.lock ~= false,
    on_done = opts.on_done,
  })
end

--- Shrink `win` along `axis`, then call `on_done(completed)`.
function M.close(win, opts)
  animate(win, { axis = opts.axis, mode = "close", on_done = opts.on_done })
end

-- Float slides keep the resting position so a reversed slide starts clean.
local function float_state(win, mode, on_done)
  M.cancel(win)
  local config = vim.api.nvim_win_get_config(win)
  local blend = vim.wo[win].winblend
  local state = { id = "panel_motion_" .. win, mode = mode, on_done = on_done }
  function state.place(offset, fade)
    vim.api.nvim_win_set_config(win, { relative = config.relative, row = config.row + offset, col = config.col })
    vim.wo[win].winblend = blend + math.floor((100 - blend) * fade + 0.5)
  end
  function state.restore()
    state.place(0, 0)
  end
  active[win] = state
  return state
end

--- Floats slide up two rows while fading in, then lock on.
function M.float_open(win)
  local state = float_state(win, "open")
  vim.w[win].dotfiles_panel_animation = true
  state.lock = motion.lock(motion.window_rect(win), { delay = motion.open.duration.total - motion.APPROACH_MS })
  motion.tween(state.id, motion.open, function(progress, done)
    if active[win] ~= state or not vim.api.nvim_win_is_valid(win) then
      return
    end
    state.place(2 * (1 - progress), 0.4 * (1 - progress))
    if done then
      release(win)
    end
  end)
end

--- Floats drop two rows while fading out, then call `on_done(completed)`.
function M.float_close(win, on_done)
  local state = float_state(win, "close", on_done)
  vim.w[win].dotfiles_panel_animation = true
  motion.tween(state.id, motion.close, function(progress, done)
    if active[win] ~= state or not vim.api.nvim_win_is_valid(win) then
      return
    end
    state.place(2 * progress, 0.8 * progress)
    if done then
      release(win)
      on_done(true)
    end
  end)
end

function M.cancel(win)
  local state = release(win)
  if state then
    motion.unlock(state.lock)
    if state.on_done then
      state.on_done(false)
    end
  end
end

function M.mode(win)
  return active[win] and active[win].mode or nil
end

function M.is_active(win)
  if win then
    return active[win] ~= nil
  end
  return next(active) ~= nil
end

return M
