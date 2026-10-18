local plugin = require("nix-plugin")

local function has_modified_buffer()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

-- Edge windows: Edgy's bars plus side panels it does not manage, such as a
-- right-hand Neo-tree, which would otherwise be left alone after :q.
local function split_windows()
  local wins = require("edgy.editor").list_wins()
  local panels, main = {}, {}
  for win in pairs(wins.edgy) do
    panels[#panels + 1] = win
  end
  for win in pairs(wins.main) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft == "neo-tree" or ft == "toggleterm" then
      panels[#panels + 1] = win
    else
      main[win] = true
    end
  end
  return panels, main
end

local function setup_exit_when_only_edges_remain()
  local exit_scheduled = false
  local group = vim.api.nvim_create_augroup("edgy_exit_when_only_edges_remain", { clear = true })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = function()
      if exit_scheduled then
        return
      end

      local panels, main = split_windows()
      local current = vim.api.nvim_get_current_win()
      if not main[current] or vim.tbl_count(main) ~= 1 or #panels == 0 then
        return
      end

      if has_modified_buffer() then
        -- Close the panels so :q sees its last window and refuses with Vim's own
        -- E37/E162. Letting the window go would leave only panels, and Edgy and
        -- Neo-tree would each try to quit or reopen a split for the buffer.
        for _, win in ipairs(panels) do
          pcall(vim.api.nvim_win_close, win, false)
        end
        return
      end

      -- Neovim can promote the last edge window before Edgy's WinClosed check.
      -- Decide while the layout is intact, then terminate terminal jobs after :q.
      exit_scheduled = true
      vim.schedule(function()
        vim.cmd("qa!")
      end)
    end,
  })
end

return {
  plugin.spec("edgy-nvim", {
    event = "VeryLazy",
    init = function()
      vim.opt.splitkeep = "screen"
    end,
    config = function()
      require("edgy").setup({
        left = {
          {
            ft = "neo-tree",
            filter = function(buf)
              return vim.b[buf].neo_tree_source == "filesystem"
            end,
          },
        },
        bottom = {
          {
            ft = "toggleterm",
            size = { height = 10 },
            filter = function(buf, win)
              local term = require("toggleterm.terminal").get(vim.b[buf].toggle_number, true)
              return vim.api.nvim_win_get_config(win).relative == "" and term and term.direction == "horizontal"
            end,
          },
        },
        options = {
          left = { size = 34 },
          bottom = { size = 10 },
        },
        -- core.panel-motion animates panels itself so it can hold Edgy off
        -- and keep terminals from re-flowing mid-animation.
        animate = { enabled = false },
        -- QuitPre above owns quitting; Edgy's plain :qa fails on unsaved buffers.
        exit_when_last = false,
        close_when_all_hidden = true,
        wo = {
          winbar = false,
          winfixwidth = true,
          winfixheight = false,
          winhighlight = "",
          spell = false,
          signcolumn = "no",
          scrolloff = 0,
        },
      })
      setup_exit_when_only_edges_remain()
    end,
  }),
}
