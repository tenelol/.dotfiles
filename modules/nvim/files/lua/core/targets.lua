-- Lock-on for the places Neovim moves you to: a window as it opens, the search
-- match you land on, and the diagnostic you jump to. Plain focus switches get
-- no frame; the Ghostty cursor reticle already marks where you went.
local motion = require("core.motion")

local M = {}

local window_lock
-- Plain windows already seen; anything else in the layout is new.
local known = {}

local function lock_range(row, first, last, opts)
  local rect = motion.text_rect(vim.api.nvim_get_current_win(), { { row = row, first = first, last = last } })
  if rect then
    motion.lock(rect, opts)
  end
end

--- Lock onto the search match under the cursor.
function M.match()
  local pattern = vim.fn.getreg("/")
  if pattern == "" then
    return
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local ok, finish = pcall(vim.fn.searchpos, pattern, "cneW", row)
  if not ok or finish[1] ~= row or finish[2] <= col then
    return
  end
  lock_range(row - 1, col + 1, finish[2])
end

--- Lock onto the diagnostic under the cursor after a jump.
function M.diagnostic()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  for _, item in ipairs(vim.diagnostic.get(0, { lnum = row - 1 })) do
    if item.col == col then
      local last = (item.end_lnum == item.lnum and item.end_col > item.col) and item.end_col or col + 1
      lock_range(row - 1, col + 1, last)
      return
    end
  end
end

local function is_plain_window(win)
  return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
end

--- Lock onto a window that just opened.
function M.window(win)
  -- Panels animate in and land their own lock.
  if not is_plain_window(win) or require("core.panel-motion").is_active(win) then
    return
  end
  local plain = vim.tbl_filter(is_plain_window, vim.api.nvim_tabpage_list_wins(0))
  if #plain < 2 then
    return
  end
  motion.unlock(window_lock)
  window_lock = motion.lock(motion.window_rect(win), { spread = 0.5 })
end

local function search_key(key, desc)
  vim.keymap.set({ "n", "x" }, key, function()
    -- An expr mapping keeps the count, wrap messages and hlsearch native.
    vim.schedule(M.match)
    return key
  end, { expr = true, desc = desc })
end

function M.setup()
  search_key("n", "Next match")
  search_key("N", "Previous match")
  search_key("*", "Search word forward")
  search_key("#", "Search word backward")
  search_key("g*", "Search partial word forward")
  search_key("g#", "Search partial word backward")

  local group = vim.api.nvim_create_augroup("LockTargets", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    pattern = { "/", "?" },
    callback = function()
      if not vim.v.event.abort then
        vim.schedule(M.match)
      end
    end,
  })
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    known[win] = true
  end
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      -- WinNew does not name the window (a float may open without focus), and
      -- the split has not settled yet, so look for unseen windows afterwards.
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not known[win] and is_plain_window(win) then
            known[win] = true
            M.window(win)
          end
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      known[tonumber(event.match)] = nil
    end,
  })
end

return M
