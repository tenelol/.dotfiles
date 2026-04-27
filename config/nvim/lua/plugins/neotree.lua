local plugin = require("nix-plugin")

return {
  plugin.spec("neo-tree-nvim", {
    dependencies = {
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
