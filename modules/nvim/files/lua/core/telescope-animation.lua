local M = {}

function M.open(prompt_bufnr)
  local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
  if not picker then
    return true
  end

  local windows = {}
  local bottom = 0
  local function add(win)
    if not win or not vim.api.nvim_win_is_valid(win) then
      return
    end
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "editor" then
      return
    end
    windows[#windows + 1] = {
      win = win,
      row = config.row,
      col = config.col,
      width = config.width,
      height = config.height,
      blend = vim.wo[win].winblend,
    }
    bottom = math.max(bottom, config.row + config.height)
  end

  for _, part in ipairs({ "prompt", "results", "preview" }) do
    add(picker[part .. "_win"])
    local border = picker[part .. "_border"]
    add(border and border.winid)
  end
  if #windows == 0 then
    return true
  end

  local usable_bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus ~= 0 and 1 or 0)
  local slide = math.min(2, math.max(0, usable_bottom - bottom))
  local function restore_blend()
    for _, state in ipairs(windows) do
      if vim.api.nvim_win_is_valid(state.win) then
        vim.wo[state.win].winblend = state.blend
      end
    end
  end

  for _, state in ipairs(windows) do
    state.current_row = state.row + slide
    if slide > 0 then
      vim.api.nvim_win_set_config(state.win, { relative = "editor", row = state.current_row, col = state.col })
    end
    vim.wo[state.win].winblend = math.min(100, state.blend + 14)
  end

  require("snacks").animate(1, 0, function(progress, ctx)
    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
      restore_blend()
      ctx.anim:stop()
      return
    end
    for _, state in ipairs(windows) do
      if not vim.api.nvim_win_is_valid(state.win) then
        restore_blend()
        ctx.anim:stop()
        return
      end
      local config = vim.api.nvim_win_get_config(state.win)
      if config.relative ~= "editor" or config.row ~= state.current_row or config.col ~= state.col
        or config.width ~= state.width or config.height ~= state.height then
        restore_blend()
        ctx.anim:stop()
        return
      end
    end

    for _, state in ipairs(windows) do
      state.current_row = state.row + slide * progress
      if slide > 0 then
        vim.api.nvim_win_set_config(state.win, { relative = "editor", row = state.current_row, col = state.col })
      end
      vim.wo[state.win].winblend = state.blend + math.floor(14 * progress + 0.5)
    end
    if ctx.done then
      restore_blend()
    end
  end, {
    id = "telescope_open_" .. prompt_bufnr,
    easing = "outQuad",
    duration = { total = 180 },
  })

  return true
end

return M
