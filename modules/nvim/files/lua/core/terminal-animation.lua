local panel = require("core.panel-motion")

local M = {}

-- Full size of each terminal's split, remembered across a close.
M.expanded = setmetatable({}, { __mode = "k" })

local function window(term)
  local win = term.window
  if term:is_open() and win and vim.api.nvim_win_is_valid(win) and term.direction ~= "tab" then
    return win
  end
end

local function axis(term)
  return term.direction == "vertical" and "width" or "height"
end

function M.open(term)
  local win = window(term)
  if not win then
    return
  end
  if term.direction == "float" then
    panel.float_open(win)
  elseif panel.mode(win) == "close" then
    panel.open(win, { axis = axis(term), size = M.expanded[term] or vim.api["nvim_win_get_" .. axis(term)](win) })
  else
    local size = vim.api["nvim_win_get_" .. axis(term)](win)
    M.expanded[term] = size
    panel.open(win, { axis = axis(term), size = size })
  end
end

function M.close(term)
  if M.is_closing(term) then
    return
  end
  local win = window(term)
  if not win then
    term:close()
    return
  end
  local function finish(completed)
    if not completed or term.window ~= win or not term:is_open() then
      return
    end
    term:close()
    -- ToggleTerm otherwise remembers the collapsed split size for the next open.
    if term.direction ~= "float" and M.expanded[term] then
      require("toggleterm.ui").save_direction_size(term.direction, M.expanded[term])
    end
  end
  if term.direction == "float" then
    panel.float_close(win, finish)
  else
    M.expanded[term] = M.expanded[term] or vim.api["nvim_win_get_" .. axis(term)](win)
    panel.close(win, { axis = axis(term), on_done = finish })
  end
end

function M.is_closing(term)
  local win = term.window
  return win ~= nil and panel.mode(win) == "close"
end

return M
