-- Run from the repository root: nvim --headless -u NONE -l modules/nvim/tests/panels.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/modules/nvim/files")
require("plugins.animate")[1].config()
local spec = require("plugins.edgy")[1]
spec.init()
spec.config()
local edgy = require("edgy")
local animation = require("edgy.animate")
local main = vim.api.nvim_get_current_win()
local cwd = vim.fn.getcwd()

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
vim.fn.writefile({ "example" }, directory .. "/example.txt")
require("plugins.neotree")[1].config()
for _ = 1, 2 do
  require("neo-tree.command").execute({ source = "filesystem", dir = directory, position = "left", action = "focus" })
  local state = require("neo-tree.sources.manager").get_state("filesystem")
  local tree_window = state.winid
  local intermediate = false
  local early_content = false
  assert(
    vim.wait(1500, function()
      local width = vim.api.nvim_win_get_width(tree_window)
      if width == 1 then
        vim.api.nvim_exec_autocmds("WinResized", {})
      end
      intermediate = intermediate or (width > 1 and width < 34)
      if width > 1 and width < 34 then
        early_content = early_content
          or table.concat(vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false), "\n"):find("example.txt", 1, true)
            ~= nil
      end
      return edgy.get_win(tree_window) and width == 34 and not animation.is_active()
    end, 5),
    "Neo-tree opening animation did not settle"
  )
  assert(intermediate, "Neo-tree snapped open without sliding")
  assert(early_content, "Neo-tree filenames appeared only after opening animation")
  assert(vim.g.minianimate_disable == false, "MiniAnimate stayed disabled after sidebar animation")
  state.commands.slide_close(state)
  local closing = false
  assert(
    vim.wait(1500, function()
      if not vim.api.nvim_win_is_valid(tree_window) then
        return true
      end
      local width = vim.api.nvim_win_get_width(tree_window)
      closing = closing or (width > 1 and width < 34)
      return false
    end, 5),
    "Neo-tree closing animation did not finish"
  )
  assert(closing, "Neo-tree snapped closed without sliding")
  vim.api.nvim_set_current_win(main)
  vim.wait(200, function()
    return false
  end)
end
vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
vim.fn.delete(directory, "rf")

require("plugins.toggleterm")[1].config()
local Terminal = require("toggleterm.terminal").Terminal
local terms = {}
for _, direction in ipairs({ "horizontal", "vertical", "float" }) do
  local term = Terminal:new({
    cmd = "cat",
    direction = direction,
    hidden = true,
    float_opts = { row = 3, col = 10, width = 48, height = 12 },
  })
  terms[#terms + 1] = term
  for _ = 1, 2 do
    term:open(10, direction)
    local win, job = term.window, term.job_id
    assert(vim.w[win].dotfiles_panel_animation, "Terminal opening animation did not start: " .. direction)
    local size = direction == "vertical" and vim.api.nvim_win_get_width or vim.api.nvim_win_get_height
    if direction ~= "float" then
      assert(size(win) < 10, "Terminal must start collapsed: " .. direction .. " " .. size(win))
    end
    vim.api.nvim_chan_send(job, "slide-test\n")
    assert(
      vim.wait(1500, function()
        return not vim.w[win].dotfiles_panel_animation and not animation.is_active()
      end, 5),
      "Terminal opening animation did not settle"
    )
    vim.api.nvim_exec_autocmds("WinResized", {})
    assert(
      vim.wait(1000, function()
        return direction ~= "horizontal" or edgy.get_win(win) ~= nil
      end),
      "Edgy did not adopt the horizontal terminal after opening"
    )
    assert(term.job_id == job and vim.fn.jobwait({ job }, 0)[1] == -1, "Animation replaced or stopped the terminal job")
    assert(
      vim.wait(1000, function()
        local output = table.concat(vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false), ""):gsub("%s", "")
        return output:find("slide-test", 1, true) ~= nil
      end),
      "Terminal output was lost during animation"
    )
    if direction == "horizontal" then
      assert(
        size(win) == 10 and edgy.get_win(win),
        "Bottom terminal layout changed: height=" .. size(win) .. " managed=" .. tostring(edgy.get_win(win) ~= nil)
      )
    elseif direction == "vertical" then
      assert(size(win) == 10 and not edgy.get_win(win), "Vertical terminal was moved to the bottom")
    else
      assert(vim.api.nvim_win_get_config(win).row == 3, "Floating terminal did not return to its intended position")
    end
    assert(vim.g.minianimate_disable ~= true, "MiniAnimate stayed disabled after terminal animation")
    term:close()
    vim.api.nvim_set_current_win(main)
    vim.wait(200, function()
      return false
    end)
  end
end
local interrupted = terms[1]
interrupted:open(10, "horizontal")
interrupted:close()
vim.wait(250, function()
  return false
end)
assert(vim.fn.jobwait({ interrupted.job_id }, 0)[1] == -1, "Closing during animation killed the terminal job")
for _, term in ipairs(terms) do
  vim.fn.jobstop(term.job_id)
end

vim.o.termguicolors = true
require("plugins.noice")[1].config()
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(
  vim.wait(1000, function()
    return require("noice.config").options.routes ~= nil
  end),
  "Noice did not initialize"
)
local notify = require("notify")._config()
assert(notify.fps() == 60 and notify.stages() == "fade_in_slide_out")
local animated_info = false
for _, route in ipairs(require("noice.config").options.routes) do
  if route.filter.event == "notify" and route.filter.kind == "info" then
    animated_info = route.view == "notify"
  end
end
assert(animated_info, "Info notifications must use the animated view")
io.write("Sidebar slide, terminal layout, animated notifications, and MiniAnimate coordination: OK\n")
