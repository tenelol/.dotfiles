local plugin = require("nix-plugin")

return {
  plugin.spec("orgmode", {
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*.org",
        org_default_notes_file = "~/org/refile.org",
        mappings = {
          prefix = "<Leader>n",
          -- The default <C-Space> is taken by the macOS IME toggle.
          org = { org_toggle_checkbox = "<prefix><Space>" },
        },
      })

      -- Quitting a modified capture makes orgmode ask about refiling from
      -- BufWipeout, where noice cannot open its confirm float, so Neovim waits
      -- on an invisible prompt. Treat :q! as discard by dropping orgmode's
      -- close hooks (augroup named in orgmode.utils.open_tmp_org_window).
      vim.api.nvim_create_autocmd("QuitPre", {
        group = vim.api.nvim_create_augroup("OrgCaptureQuit", { clear = true }),
        callback = function(args)
          local buf = args.buf
          if not (vim.b[buf].org_capture and vim.bo[buf].modified) then
            return
          end
          local group = "OrgTmpWindow_" .. buf
          local ok, hooks = pcall(vim.api.nvim_get_autocmds, { group = group })
          if not ok then
            return
          end
          vim.api.nvim_del_augroup_by_name(group)
          -- A plain :q fails with E37 and keeps the capture open, so restore
          -- the hooks to let a later :wq still refile it.
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local id = vim.api.nvim_create_augroup(group, { clear = true })
            for _, hook in ipairs(hooks) do
              vim.api.nvim_create_autocmd(hook.event, {
                group = id,
                buffer = hook.buffer,
                callback = hook.callback,
                once = hook.once,
              })
            end
          end)
        end,
      })
    end,
  }),
}
