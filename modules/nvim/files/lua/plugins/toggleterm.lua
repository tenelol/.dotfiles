local plugin = require("nix-plugin")
local theme = require("core.theme")

return {
  plugin.spec("toggleterm-nvim", {
    dependencies = { plugin.dep("edgy-nvim"), plugin.dep("snacks-nvim") },
    cmd = { "ClaudeCode", "Codex", "ToggleTerm", "TermExec", "TermNew", "TermSelect", "ToggleTermToggleAll" },
    keys = {
      { "<C-\\>", mode = { "n", "t" }, desc = "Toggle terminal" },
      { "<C-t>", desc = "Toggle floating terminal" },
      { "[T", desc = "Previous terminal" },
      { "]T", desc = "Next terminal" },
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
          fg = theme.fg_bright,
          bg = theme.bg_highlight,
          bold = true,
        })
        vim.api.nvim_set_hl(0, "WinBarInactive", {
          fg = theme.fg_dark,
          bg = "none",
        })
      end

      require("toggleterm").setup({
        size = 10,
        shade_terminals = true,
        direction = "horizontal",
        persist_mode = true,
        start_in_insert = true,
        on_open = require("core.terminal-animation").open,
        winbar = {
          enabled = true,
          name_formatter = terminal_label,
        },
      })

      apply_winbar_highlights()

      map("n", "<C-\\>", function()
        terminal.toggle(vim.v.count)
      end, { silent = true, desc = "Toggle terminal" })

      map("t", "<C-\\>", function()
        local _, term = require("toggleterm.terminal").identify()
        if term then
          terminal.close(term)
        end
      end, { silent = true, desc = "Toggle terminal" })

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

      map("t", "<C-t>", function()
        terminal.toggle_float()
      end, { silent = true, desc = "Toggle floating terminal" })

      map({ "n", "t" }, "]T", function()
        terminal.next()
      end, { silent = true, desc = "Next terminal" })

      map({ "n", "t" }, "[T", function()
        terminal.previous()
      end, { silent = true, desc = "Previous terminal" })
    end,
  }),
}
