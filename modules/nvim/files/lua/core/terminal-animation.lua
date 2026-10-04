local M = {}
local active = {}

local function stop(term)
  local state = active[term]
  if not state then
    return
  end
  require("snacks").animate.del("toggleterm_slide_" .. term.id)
  if vim.api.nvim_win_is_valid(state.win) then
    vim.w[state.win].edgy_disable = state.edgy_disabled
    vim.w[state.win].dotfiles_panel_animation = nil
  end
  active[term] = nil
  return state
end

local function animate(term, opening)
  local previous = stop(term)
  if not term:is_open() or term.direction == "tab" then
    if not opening then
      term:close()
    end
    return
  end

  local win = term.window
  local config = vim.api.nvim_win_get_config(win)
  local current, apply
  if config.relative ~= "" then
    current = config.row
    apply = function(row)
      vim.api.nvim_win_set_config(win, { relative = config.relative, win = config.win, row = row, col = config.col })
    end
  else
    local axis = term.direction == "vertical" and "width" or "height"
    current = vim.api["nvim_win_get_" .. axis](win)
    apply = function(size)
      vim.api["nvim_win_set_" .. axis](win, size)
    end
  end
  local continuing = previous and previous.win == win
  local expanded = continuing and previous.expanded or current
  local collapsed = config.relative ~= "" and math.max(expanded + 1, vim.o.lines - config.height - 3) or 1
  local from = opening and not continuing and collapsed or current
  local target = opening and expanded or collapsed
  active[term] = { win = win, expanded = expanded, opening = opening, edgy_disabled = vim.w[win].edgy_disable }
  vim.w[win].edgy_disable = true
  vim.w[win].dotfiles_panel_animation = true
  apply(from)
  require("snacks").animate(from, target, function(value, ctx)
    if not vim.api.nvim_win_is_valid(win) or term.window ~= win or vim.api.nvim_win_get_buf(win) ~= term.bufnr then
      stop(term)
      return
    end
    apply(ctx.done and target or value)
    if ctx.done then
      stop(term)
      if not opening then
        term:close()
        -- ToggleTerm otherwise remembers the collapsed split size for the next open.
        if config.relative == "" then
          require("toggleterm.ui").save_direction_size(term.direction, expanded)
        end
      end
    end
  end, {
    id = "toggleterm_slide_" .. term.id,
    int = true,
    easing = "linear",
    duration = { step = 15, total = 180 },
  })
end

function M.open(term)
  animate(term, true)
end

function M.close(term)
  if not M.is_closing(term) then
    animate(term, false)
  end
end

function M.is_closing(term)
  return active[term] and not active[term].opening
end

return M
