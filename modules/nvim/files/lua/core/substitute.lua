-- Prefilled :substitute so the pattern syntax never has to be typed. The
-- search text is literal (\V), the replacement starts as the original text,
-- and the cursor waits at its end: edit it and press Enter. The live preview
-- comes from 'inccommand'. For multi-file or regex-heavy edits use grug-far
-- (<leader>rf, <leader>rr).
local M = {}

-- In a \V pattern only \ and the delimiter are special; a replacement also
-- treats & and ~ as the match and the previous replacement.
local function escape_pattern(text)
  return vim.fn.escape(text, [[\/]])
end

local function escape_replacement(text)
  return vim.fn.escape(text, [[\/&~]])
end

-- Command line with the cursor parked before the trailing "/g". Only the
-- cursor keys go through termcodes so text like "<CR>" stays literal, and the
-- keys go in front of any typeahead so fast typing lands in the command line.
local function prefill(pattern, replacement)
  local function key(notation)
    return vim.api.nvim_replace_termcodes(notation, true, false, true)
  end
  -- From Visual mode ":" starts with '<,'>; <C-u> clears it so the whole
  -- buffer is searched.
  local keys = ":" .. key("<C-u>") .. "%s/" .. pattern .. "/" .. replacement .. "/g" .. key("<Left><Left>")
  vim.api.nvim_feedkeys(keys, "ni", false)
end

function M.word()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return
  end
  prefill([[\V\<]] .. escape_pattern(word) .. [[\>]], escape_replacement(word))
end

function M.selection()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
  if #lines ~= 1 or lines[1] == "" then
    vim.notify("Select text on one line to replace it", vim.log.levels.WARN)
    return
  end
  prefill([[\V]] .. escape_pattern(lines[1]), escape_replacement(lines[1]))
end

function M.setup()
  vim.keymap.set("n", "<leader>rw", M.word, { desc = "Replace word in buffer" })
  vim.keymap.set("x", "<leader>rw", M.selection, { desc = "Replace selection in buffer" })
end

return M
