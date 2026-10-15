-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/panel-reveal.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
vim.o.columns, vim.o.lines = 80, 24
local reveal = require("core.panel-reveal")
local ns = vim.api.nvim_get_namespaces().dotfiles_panel_reveal

local function overlay()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return win
    end
  end
end

local function chunks(win)
  local marks = vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(win), ns, 0, -1, { details = true })
  local out = {}
  for _, mark in ipairs(marks) do
    for _, chunk in ipairs(mark[4].virt_text) do
      out[#out + 1] = chunk
    end
  end
  return out
end

local partial = "[▏▎▍▌▋▊▉▕🮇🮈▐🮉🮊🮋▁▂▃▄▅▆▇▔🮂🮃▀🮄🮅🮆]"
local cases = {
  { edge = "left", setup = "vsplit", axis = "col" },
  { edge = "right", setup = "rightbelow vsplit", axis = "col" },
  { edge = "bottom", setup = "rightbelow split", axis = "row" },
  { edge = "top", setup = "split", axis = "row" },
}
for _, case in ipairs(cases) do
  vim.cmd("silent! only")
  vim.cmd(case.setup)
  local win = vim.api.nvim_get_current_win()
  local positions, saw_partial = {}, false
  reveal.play(win, { edge = case.edge, mode = "open", duration = 240 })
  assert(vim.wait(1000, function()
    local float = overlay()
    if float then
      positions[#positions + 1] = vim.api.nvim_win_get_config(float)[case.axis]
      for _, chunk in ipairs(chunks(float)) do
        saw_partial = saw_partial or vim.fn.match(chunk[1], partial) >= 0
      end
    end
    return not reveal.is_active(win)
  end, 4), "Reveal did not finish: " .. case.edge)
  assert(saw_partial, "Bar never used an eighth-block edge: " .. case.edge)
  assert(overlay() == nil, "Overlay leaked: " .. case.edge)
  -- The covered region only ever shrinks toward the far edge while opening.
  local toward = (case.edge == "left" or case.edge == "top") and 1 or -1
  for i = 2, #positions do
    assert((positions[i] - positions[i - 1]) * toward >= 0, "Overlay moved backwards: " .. case.edge)
  end
end

-- Cancelling reports an incomplete sweep and leaves no overlay behind.
vim.cmd("silent! only | vsplit")
local win = vim.api.nvim_get_current_win()
local result
reveal.play(win, { edge = "left", mode = "close", on_done = function(completed) result = completed end })
assert(reveal.mode(win) == "close" and vim.w[win].dotfiles_panel_animation)
reveal.play(win, { edge = "left", mode = "open" })
assert(result == false, "Replacing a sweep must cancel the previous one")
assert(reveal.mode(win) == "open")
reveal.cancel(win)
assert(overlay() == nil and not vim.w[win].dotfiles_panel_animation, "Cancel left state behind")
print("Eighth-block edges, sweep direction on all edges, cancel, and cleanup: OK")
