local plugin = require("nix-plugin")

local function has_modified_buffer()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
      return true
    end
  end
  return false
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

      local wins = require("edgy.editor").list_wins()
      local current = vim.api.nvim_get_current_win()
      if not wins.main[current] or vim.tbl_count(wins.main) ~= 1 or vim.tbl_isempty(wins.edgy) then
        return
      end

      if has_modified_buffer() then
        vim.schedule(function()
          vim.notify("Unsaved buffers remain; Neovim was kept open.", vim.log.levels.WARN, { title = "Exit" })
        end)
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
            filter = function(_, win)
              return vim.api.nvim_win_get_config(win).relative == ""
            end,
          },
        },
        options = {
          left = { size = 34 },
          bottom = { size = 10 },
        },
        animate = {
          enabled = false,
        },
        exit_when_last = true,
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
