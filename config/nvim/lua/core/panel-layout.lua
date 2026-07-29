local M = {}

local function window_filetype(win)
  if not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype
end

local function neo_tree_source(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ok, source = pcall(vim.api.nvim_buf_get_var, buf, "neo_tree_source")

  return ok and source or nil
end

function M.terminal_height()
  local available_lines = vim.o.lines - vim.o.cmdheight
  return math.max(9, math.min(14, math.floor(available_lines * 0.22)))
end

function M.pin_sidebar(win)
  if window_filetype(win) ~= "neo-tree" then
    return
  end

  local source = neo_tree_source(win)
  local edge = (source == "buffers" or source == "git_status") and "L" or "H"

  pcall(vim.api.nvim_win_call, win, function()
    vim.wo.winfixwidth = true
    vim.cmd("wincmd " .. edge)
  end)
end

function M.pin_sidebars(focus_win)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    M.pin_sidebar(win)
  end

  if focus_win and vim.api.nvim_win_is_valid(focus_win) then
    vim.api.nvim_set_current_win(focus_win)
  end
end

function M.dock_terminal(term)
  if term.direction ~= "horizontal" or not term.window or not vim.api.nvim_win_is_valid(term.window) then
    return
  end

  M.pin_sidebars(term.window)

  vim.wo[term.window].winfixheight = true
  pcall(vim.api.nvim_win_set_height, term.window, M.terminal_height())
end

return M
