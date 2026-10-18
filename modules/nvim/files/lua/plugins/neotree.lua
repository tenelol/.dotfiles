local plugin = require("nix-plugin")
local theme = require("core.theme")

local function is_side_panel(state, win)
  return state.current_position ~= "current" and vim.api.nvim_win_get_config(win).relative == ""
end

-- Inner width neo-tree should lay out for while a panel animates. Its
-- containers right-align to the measured width, and its resize monitor
-- re-renders on every change, so git and diagnostic icons would otherwise
-- slide across the panel as it grows or shrinks.
local settling = {}
local measure_patched = false

local function hold_layout(win)
  local utils = require("neo-tree.utils")
  if not measure_patched then
    measure_patched = true
    local measure = utils.get_inner_win_width
    utils.get_inner_win_width = function(winid)
      return settling[winid] or measure(winid)
    end
  end
  settling[win] = settling[win] or utils.get_inner_win_width(win)
  return function()
    settling[win] = nil
  end
end

local function close_tree(state)
  local win = state.winid
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local panel = require("core.panel-motion")
  if not is_side_panel(state, win) then
    require("neo-tree.ui.renderer").close(state)
    return
  end
  if panel.mode(win) == "close" then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local release = hold_layout(win)
  panel.close(win, {
    axis = "width",
    on_done = function(completed)
      release()
      if completed and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        require("neo-tree.ui.renderer").close(state)
      end
    end,
  })
end

local function open_tree(event)
  local win = event and event.winid
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local state = require("neo-tree.sources.manager").get_state(event.source)
  if is_side_panel(state, win) then
    -- Measured before the panel collapses, so the first render uses the final width.
    local release = hold_layout(win)
    require("core.panel-motion").open(win, { axis = "width", size = vim.api.nvim_win_get_width(win), on_done = release })
  end
end

return {
  plugin.spec("neo-tree-nvim", {
    dependencies = {
      plugin.dep("edgy-nvim"),
      plugin.dep("snacks-nvim"),
      plugin.dep("plenary-nvim"),
      plugin.dep("nvim-web-devicons"),
      plugin.dep("nui-nvim"),
    },
    cmd = { "Neotree", "GitTree" },
    keys = {
      { "<C-n>", desc = "Toggle file tree" },
      { "<leader>ef", desc = "Explorer filesystem" },
      { "<leader>eb", desc = "Explorer buffers" },
      { "<leader>eg", desc = "Explorer git status" },
      { "<leader>gt", desc = "Git tree" },
    },
    config = function()
      local project = require("core.project")
      local command = require("neo-tree.command")

      local transparent_groups = {
        "NeoTreeNormal",
        "NeoTreeNormalNC",
        "NeoTreeEndOfBuffer",
        "NeoTreeWinSeparator",
        "NeoTreeVertSplit",
        "NeoTreeFloatNormal",
        "NeoTreeFloatBorder",
        "NeoTreeTitleBar",
        "NeoTreeTabActive",
        "NeoTreeTabInactive",
        "NeoTreeTabSeparatorActive",
        "NeoTreeTabSeparatorInactive",
      }

      local function clear_group_background(group)
        local ok, highlight = pcall(vim.api.nvim_get_hl, 0, {
          name = group,
          link = false,
        })
        if not ok then
          return
        end

        highlight.bg = "NONE"
        highlight.ctermbg = nil
        vim.api.nvim_set_hl(0, group, highlight)
      end

      local function apply_transparent_highlights()
        for _, group in ipairs(transparent_groups) do
          clear_group_background(group)
        end
        vim.api.nvim_set_hl(0, "NeoTreeFileName", { fg = theme.fg_bright })
        vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = theme.fg })
      end

      require("neo-tree").setup({
        -- Quitting is handled by the QuitPre hook in plugins/edgy.lua; Neo-tree's
        -- own version opens a new split for every unsaved buffer instead.
        close_if_last_window = false,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        commands = { slide_close = close_tree },
        event_handlers = {
          { event = "neo_tree_window_after_open", handler = open_tree },
        },
        default_component_configs = {
          container = { min_width = 28 },
          name = {
            use_git_status_colors = false,
          },
          diagnostics = {
            symbols = {
              hint = "H",
              info = "I",
              warn = "W",
              error = "E",
            },
            highlights = {
              hint = "DiagnosticSignHint",
              info = "DiagnosticSignInfo",
              warn = "DiagnosticSignWarn",
              error = "DiagnosticSignError",
            },
          },
          git_status = {
            symbols = {
              untracked = "·",
            },
          },
        },
        filesystem = {
          find_by_full_path_words = true,
          window = {
            mappings = {
              ["/"] = "fuzzy_finder",
              ["f"] = "filter_as_you_type",
              ["<C-x>"] = "clear_filter",
            },
          },
          follow_current_file = {
            enabled = true,
            leave_dirs_open = false,
          },
          hijack_netrw_behavior = "open_default",
          -- Per-directory watchers can exhaust file descriptors in large trees
          -- and cause repeated filesystem and Git refreshes.
          use_libuv_file_watcher = false,
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = false,
          },
        },
        buffers = {
          follow_current_file = {
            enabled = true,
          },
          group_empty_dirs = true,
          show_unloaded = true,
        },
        window = {
          width = 34,
          mappings = { ["q"] = "slide_close" },
        },
      })

      local highlight_group = vim.api.nvim_create_augroup("NeoTreeTransparentHighlights", { clear = true })

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = highlight_group,
        callback = apply_transparent_highlights,
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = highlight_group,
        pattern = "neo-tree",
        callback = function()
          vim.schedule(apply_transparent_highlights)
        end,
      })
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = highlight_group,
        callback = function(event)
          if vim.bo[event.buf].filetype == "neo-tree" then
            vim.schedule(apply_transparent_highlights)
          end
        end,
      })
      apply_transparent_highlights()

      local function open_filesystem_tree()
        local state = require("neo-tree.sources.manager").get_state("filesystem")
        if state.winid and vim.api.nvim_win_is_valid(state.winid) then
          close_tree(state)
          return
        end
        command.execute({
          source = "filesystem",
          toggle = true,
          reveal = true,
          dir = project.buffer_root(0),
          position = "left",
        })
      end

      local function open_git_status_tree()
        command.execute({
          source = "git_status",
          toggle = true,
          position = "right",
        })
      end

      vim.api.nvim_create_user_command("GitTree", open_git_status_tree, {
        desc = "Open git status tree",
      })

      local map = vim.keymap.set

      map("n", "<C-n>", open_filesystem_tree, { desc = "Toggle file tree" })
      map("n", "<leader>ef", open_filesystem_tree, { desc = "Explorer filesystem" })
      map("n", "<leader>eb", function()
        command.execute({
          source = "buffers",
          toggle = true,
          position = "right",
        })
      end, { desc = "Explorer buffers" })
      map("n", "<leader>eg", open_git_status_tree, { desc = "Explorer git status" })
      map("n", "<leader>gt", open_git_status_tree, { desc = "Git tree" })
    end,
  }),
}
