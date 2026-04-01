local plugin = require("nix-plugin")

return {
  plugin.spec("neo-tree-nvim", {
    dependencies = {
      plugin.dep("plenary-nvim"),
      plugin.dep("nvim-web-devicons"),
      plugin.dep("nui-nvim"),
    },
    config = function()
      local project = require("core.project")
      local command = require("neo-tree.command")

      require("neo-tree").setup({
        close_if_last_window = true,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        filesystem = {
          follow_current_file = {
            enabled = true,
            leave_dirs_open = false,
          },
          hijack_netrw_behavior = "open_default",
          use_libuv_file_watcher = true,
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
        },
      })

      local function open_filesystem_tree()
        command.execute({
          source = "filesystem",
          toggle = true,
          reveal = true,
          dir = project.buffer_root(0),
          position = "left",
        })
      end

      vim.keymap.set("n", "<C-n>", open_filesystem_tree, { desc = "Toggle file tree" })
      vim.keymap.set("n", "<leader>ef", open_filesystem_tree, { desc = "Explorer filesystem" })
      vim.keymap.set("n", "<leader>eb", function()
        command.execute({
          source = "buffers",
          toggle = true,
          position = "right",
        })
      end, { desc = "Explorer buffers" })
      vim.keymap.set("n", "<leader>eg", function()
        command.execute({
          source = "git_status",
          toggle = true,
          position = "right",
        })
      end, { desc = "Explorer git status" })
    end,
  }),
}
