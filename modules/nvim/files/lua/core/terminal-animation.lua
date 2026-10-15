-- Terminals open at full size so the shell never re-flows mid-animation; the
-- light-bar reveal hides and shows them instead.
local reveal = require("core.panel-reveal")

local M = {}

local EDGE = { horizontal = "bottom", vertical = "right", float = "bottom" }

local function window(term)
  local win = term.window
  if term:is_open() and win and vim.api.nvim_win_is_valid(win) and term.direction ~= "tab" then
    return win
  end
end

function M.open(term)
  local win = window(term)
  if win then
    reveal.play(win, { edge = EDGE[term.direction], mode = "open" })
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
  reveal.play(win, {
    edge = EDGE[term.direction],
    mode = "close",
    on_done = function(completed)
      if completed and term.window == win and term:is_open() then
        term:close()
      end
    end,
  })
end

function M.is_closing(term)
  local win = term.window
  return win ~= nil and reveal.mode(win) == "close"
end

return M
