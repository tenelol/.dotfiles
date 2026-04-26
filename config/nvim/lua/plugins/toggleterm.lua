local plugin = require("nix-plugin")

return {
  plugin.spec("toggleterm-nvim", {
    cmd = { "ClaudeCode", "Codex", "ToggleTerm", "TermExec", "TermNew", "TermSelect", "ToggleTermToggleAll" },
    keys = {
      { "<C-\\>", desc = "Toggle terminal" },
      { "<C-t>", desc = "Toggle floating terminal" },
      { "<leader>iC", desc = "Open Claude Code" },
      { "<leader>ix", desc = "Open Codex CLI" },
      { "<leader>ot", desc = "New terminal" },
      { "<leader>oT", desc = "Select terminal" },
      { "<leader>oa", desc = "Toggle all terminals" },
      { "[T", desc = "Previous terminal" },
      { "]T", desc = "Next terminal" },
      { "<leader>to", desc = "Toggle test output" },
    },
    config = function()
      local terminal = require("core.terminal")
      local map = vim.keymap.set
      local augroup = vim.api.nvim_create_augroup("ToggleTermWinbarStyle", { clear = true })

      local function terminal_label(term)
        local name = term.display_name or ""

        if name == "TypeScript watch" then
          return (" TSC %d "):format(term.id)
        end

        if name == "Tests" then
          return (" TEST %d "):format(term.id)
        end

        if name == "" or name:match("^Shell %d+$") then
          return (" TERM %d "):format(term.id)
        end

        return (" %d %s "):format(term.id, name:upper())
      end

      local function apply_winbar_highlights()
        vim.api.nvim_set_hl(0, "WinBarActive", {
          fg = "#0A111D",
          bg = "#7CC6FF",
          bold = true,
        })
        vim.api.nvim_set_hl(0, "WinBarInactive", {
          fg = "#E9F2FF",
          bg = "#2F3F5E",
          bold = true,
        })
      end

      require("toggleterm").setup({
        size = 10,
        open_mapping = [[<C-\>]],
        shade_terminals = true,
        direction = "horizontal",
        persist_mode = true,
        start_in_insert = true,
        winbar = {
          enabled = true,
          name_formatter = terminal_label,
        },
      })

      apply_winbar_highlights()

      vim.api.nvim_create_user_command("ClaudeCode", function()
        terminal.claude()
      end, { desc = "Open Claude Code" })

      vim.api.nvim_create_user_command("Codex", function()
        terminal.codex()
      end, { desc = "Open Codex CLI" })

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = apply_winbar_highlights,
      })

      map("n", "<C-t>", function()
        terminal.toggle_float()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("n", "<leader>iC", function()
        terminal.claude()
      end, { silent = true, desc = "Open Claude Code" })

      map("n", "<leader>ix", function()
        terminal.codex()
      end, { silent = true, desc = "Open Codex CLI" })

      map("t", "<C-t>", function()
        terminal.toggle_float()
      end, { silent = true, desc = "Toggle floating terminal" })

      map("n", "<leader>ot", function()
        terminal.new()
      end, { silent = true, desc = "New terminal" })

      map("n", "<leader>oT", function()
        terminal.select()
      end, { silent = true, desc = "Select terminal" })

      map("n", "<leader>oa", function()
        terminal.toggle_all()
      end, { silent = true, desc = "Toggle all terminals" })

      map({ "n", "t" }, "]T", function()
        terminal.next()
      end, { silent = true, desc = "Next terminal" })

      map({ "n", "t" }, "[T", function()
        terminal.previous()
      end, { silent = true, desc = "Previous terminal" })

      map("n", "<leader>to", function()
        require("core.test-terminal").toggle()
      end, { silent = true, desc = "Toggle test output" })
    end,
  }),
}
