local plugin = require("nix-plugin")

return {
  plugin.spec("orgmode", {
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*.org",
        org_default_notes_file = "~/org/refile.org",
        -- A plain note by default, stamped like Orgnote's captures; a task is a
        -- <Leader>t away. The default t entry is merged in, so it is redefined.
        org_capture_templates = {
          m = { description = "メモ", template = "* %?\n  %U" },
          t = { description = "TODO", template = "* TODO %?\n  %U" },
        },
        mappings = {
          prefix = "<Leader>n",
          -- The default <C-Space> is taken by the macOS IME toggle.
          org = { org_toggle_checkbox = "<prefix><Space>" },
        },
      })

      -- The everyday actions on <Leader> + one key; the full set stays under <Leader>n.
      local org = require("orgmode")
      local function action(name)
        return function()
          org.action(name)
        end
      end
      vim.keymap.set("n", "<Leader>a", action("agenda.prompt"), { desc = "Org agenda" })
      -- Straight into a memo; <Leader>nc still offers the TODO template.
      vim.keymap.set("n", "<Leader>q", function()
        org.action("capture.open_template_by_shortcut", "m")
      end, { desc = "New memo" })
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("OrgShortKeys", { clear = true }),
        pattern = "org",
        callback = function(args)
          -- nowait: these shadow the test, problems, session, debug and replace
          -- groups, but only inside org buffers, where those are rarely wanted.
          for lhs, spec in pairs({
            ["<Leader>t"] = { "org_mappings.todo_next_state", "Next TODO state" },
            ["<Leader>x"] = { "org_mappings.toggle_checkbox", "Toggle checkbox" },
            ["<Leader>s"] = { "org_mappings.org_schedule", "Schedule" },
            ["<Leader>d"] = { "org_mappings.org_deadline", "Deadline" },
            ["<Leader>r"] = { "capture.refile_headline_to_destination", "Refile" },
          }) do
            vim.keymap.set("n", lhs, action(spec[1]), { buffer = args.buf, nowait = true, desc = spec[2] })
          end
        end,
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
