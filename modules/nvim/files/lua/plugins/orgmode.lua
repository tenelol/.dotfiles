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
    end,
  }),
}
