local plugin = require("nix-plugin")
local theme = require("core.theme")

local function animate_open(term)
  local win = term.window
  local config = vim.api.nvim_win_get_config(win)
  local from, target, apply
  if config.relative ~= "" then
    target = config.row
    from = math.max(target + 1, vim.o.lines - config.height - 3)
    apply = function(row)
      vim.api.nvim_win_set_config(win, { relative = config.relative, win = config.win, row = row, col = config.col })
    end
  else
    local axis = term.direction == "vertical" and "width" or "height"
    from, target = 1, vim.api["nvim_win_get_" .. axis](win)
    apply = function(size)
      vim.api["nvim_win_set_" .. axis](win, size)
    end
  end
  local edgy_disabled = vim.w[win].edgy_disable
  vim.w[win].edgy_disable = true
  vim.w[win].dotfiles_panel_animation = true
  apply(from)
  require("snacks").animate(from, target, function(value, ctx)
    if not vim.api.nvim_win_is_valid(win) then
      ctx.anim:stop()
      return
    end
    if vim.api.nvim_win_get_buf(win) ~= term.bufnr then
      vim.w[win].edgy_disable = edgy_disabled
      vim.w[win].dotfiles_panel_animation = nil
      ctx.anim:stop()
      return
    end
    apply(ctx.done and target or value)
    if ctx.done then
      vim.w[win].edgy_disable = edgy_disabled
      vim.w[win].dotfiles_panel_animation = nil
    end
  end, {
    id = "toggleterm_open_" .. term.id,
    int = true,
    easing = "linear",
    duration = { step = 15, total = 180 },
  })
end

return {
  plugin.spec("toggleterm-nvim", {
    dependencies = { plugin.dep("edgy-nvim"), plugin.dep("snacks-nvim") },
    cmd = { "ClaudeCode", "Codex", "ToggleTerm", "TermExec", "TermNew", "TermSelect", "ToggleTermToggleAll" },
    keys = {
      { "<C-\\>", desc = "Toggle terminal" },
      { "<C-t>", desc = "Toggle floating terminal" },
      { "<leader>iC", desc = "Open Claude Code" },
      { "<leader>ix", desc = "Open Codex CLI" },
      { "<leader>ot", desc = "New terminal" },
      { "<leader>oT", desc = "Select terminal" },
      { "<leader>oa", desc = "Toggle all terminals" },
      { "<leader>on", desc = "Next terminal" },
      { "<leader>op", desc = "Previous terminal" },
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
        on_open = animate_open,
        winbar = {
          enabled = true,
          name_formatter = terminal_label,
        },
      })

      apply_winbar_highlights()

      map("n", "<C-\\>", function()
        terminal.toggle(vim.v.count)
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

      map("n", "<leader>on", function()
        terminal.next()
      end, { silent = true, desc = "Next terminal" })

      map("n", "<leader>op", function()
        terminal.previous()
      end, { silent = true, desc = "Previous terminal" })

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
