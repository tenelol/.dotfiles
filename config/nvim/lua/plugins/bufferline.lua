local plugin = require("nix-plugin")
local theme = require("core.theme")

local function close_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.bo[bufnr].modified then
    vim.cmd("buffer " .. bufnr)
    vim.notify("Buffer has unsaved changes", vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
  end
end

local function neo_tree_title()
  local labels = {
    filesystem = "File Explorer",
    buffers = "Buffers",
    git_status = "Git Status",
  }

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      local ok, source = pcall(vim.api.nvim_buf_get_var, buf, "neo_tree_source")
      return labels[ok and source or nil] or "Neo-tree"
    end
  end

  return "File Explorer"
end

local function diagnostics_indicator(_, _, diagnostics)
  diagnostics = diagnostics or {}

  local parts = {}
  local icons = {
    error = " ",
    warning = " ",
    info = " ",
    hint = " ",
  }

  for _, level in ipairs({ "error", "warning", "info", "hint" }) do
    local count = diagnostics[level]
    if count and count > 0 then
      table.insert(parts, icons[level] .. count)
    end
  end

  return #parts > 0 and " " .. table.concat(parts, " ") or ""
end

return {
  plugin.spec("bufferline-nvim", {
    dependencies = {
      plugin.dep("nvim-web-devicons"),
    },
    lazy = false,
    config = function()
      local bufferline = require("bufferline")
      local map = vim.keymap.set

      vim.api.nvim_set_hl(0, "NeoTreeOffset", { fg = theme.yellow, bg = theme.bg_dark, bold = true })

      bufferline.setup({
        options = {
          mode = "buffers",
          style_preset = bufferline.style_preset.default,
          themable = true,
          numbers = "none",
          close_command = close_buffer,
          right_mouse_command = close_buffer,
          left_mouse_command = "buffer %d",
          middle_mouse_command = close_buffer,
          indicator = {
            style = "underline",
          },
          buffer_close_icon = "×",
          modified_icon = "●",
          close_icon = "",
          left_trunc_marker = "‹",
          right_trunc_marker = "›",
          max_name_length = 24,
          max_prefix_length = 12,
          truncate_names = true,
          tab_size = 20,
          diagnostics = "nvim_lsp",
          diagnostics_update_on_event = true,
          diagnostics_indicator = diagnostics_indicator,
          offsets = {
            {
              filetype = "neo-tree",
              text = neo_tree_title,
              highlight = "NeoTreeOffset",
              text_align = "center",
              separator = true,
            },
            {
              filetype = "NvimTree",
              text = "File Explorer",
              highlight = "NeoTreeOffset",
              text_align = "center",
              separator = true,
            },
          },
          color_icons = true,
          show_buffer_icons = true,
          show_buffer_close_icons = true,
          show_close_icon = false,
          show_tab_indicators = false,
          show_duplicate_prefix = true,
          persist_buffer_sort = true,
          move_wraps_at_ends = true,
          separator_style = "slant",
          enforce_regular_tabs = false,
          always_show_bufferline = true,
          hover = {
            enabled = true,
            delay = 150,
            reveal = { "close" },
          },
          sort_by = "insert_after_current",
        },
        highlights = {
          fill = { bg = "none" },
          background = { fg = theme.fg_gutter, bg = "none" },
          buffer_visible = { fg = theme.fg_dark, bg = "none" },
          buffer_selected = { fg = theme.fg, bg = theme.bg_highlight, bold = true, italic = false },
          close_button = { fg = theme.fg_gutter, bg = "none" },
          close_button_visible = { fg = theme.fg_gutter, bg = "none" },
          close_button_selected = { fg = theme.fg_dark, bg = theme.bg_highlight },
          modified = { fg = theme.yellow, bg = "none" },
          modified_visible = { fg = theme.yellow, bg = "none" },
          modified_selected = { fg = theme.yellow, bg = theme.bg_highlight },
          duplicate = { fg = theme.fg_gutter, bg = "none", italic = false },
          duplicate_visible = { fg = theme.fg_dark, bg = "none", italic = false },
          duplicate_selected = { fg = theme.fg, bg = theme.bg_highlight, italic = false },
          separator = { fg = theme.bg_dark, bg = "none" },
          separator_visible = { fg = theme.bg_dark, bg = "none" },
          separator_selected = { fg = theme.bg_dark, bg = theme.bg_highlight },
          indicator_selected = { fg = theme.blue, bg = theme.bg_highlight },
          offset_separator = { fg = theme.fg_gutter, bg = "none" },
          trunc_marker = { fg = theme.fg_gutter, bg = "none" },
          diagnostic = { fg = theme.fg_gutter, bg = "none" },
          diagnostic_visible = { fg = theme.fg_gutter, bg = "none" },
          diagnostic_selected = { fg = theme.fg_dark, bg = theme.bg_highlight },
          error = { fg = theme.red, bg = "none" },
          error_visible = { fg = theme.red, bg = "none" },
          error_selected = { fg = theme.red, bg = theme.bg_highlight },
          warning = { fg = theme.yellow, bg = "none" },
          warning_visible = { fg = theme.yellow, bg = "none" },
          warning_selected = { fg = theme.yellow, bg = theme.bg_highlight },
          info = { fg = theme.cyan, bg = "none" },
          info_visible = { fg = theme.cyan, bg = "none" },
          info_selected = { fg = theme.cyan, bg = theme.bg_highlight },
        },
      })

      map("n", "[b", "<Cmd>BufferLineCyclePrev<CR>", { silent = true, desc = "Previous buffer" })
      map("n", "]b", "<Cmd>BufferLineCycleNext<CR>", { silent = true, desc = "Next buffer" })
      map("n", "<leader>bb", "<Cmd>BufferLinePick<CR>", { silent = true, desc = "Pick buffer" })
      map("n", "<leader>bc", function()
        close_buffer()
      end, { silent = true, desc = "Close buffer" })
      map("n", "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", { silent = true, desc = "Close other buffers" })
      map("n", "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", { silent = true, desc = "Toggle pin" })
      map("n", "<leader>bH", "<Cmd>BufferLineMovePrev<CR>", { silent = true, desc = "Move buffer left" })
      map("n", "<leader>bL", "<Cmd>BufferLineMoveNext<CR>", { silent = true, desc = "Move buffer right" })

      for i = 1, 9 do
        map("n", "<A-" .. i .. ">", "<Cmd>BufferLineGoToBuffer " .. i .. "<CR>", {
          silent = true,
          desc = "Go to buffer " .. i,
        })
      end
      map("n", "<A-0>", "<Cmd>BufferLineGoToBuffer -1<CR>", { silent = true, desc = "Go to last buffer" })
    end,
  }),
}
