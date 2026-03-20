local plugin = require("nix-plugin")

return {
  plugin.spec("emmet-vim", {
    ft = {
      "html",
      "css",
      "scss",
      "javascriptreact",
      "typescriptreact",
      "astro",
    },
    init = function()
      vim.g.user_emmet_install_global = 0
      vim.g.user_emmet_settings = {
        javascriptreact = {
          extends = "html",
        },
        typescriptreact = {
          extends = "html",
        },
        astro = {
          extends = "html",
        },
      }
    end,
    config = function()
      local emmet_group = vim.api.nvim_create_augroup("EmmetInstall", { clear = true })

      vim.cmd("EmmetInstall")
      vim.api.nvim_create_autocmd("FileType", {
        group = emmet_group,
        pattern = {
          "html",
          "css",
          "scss",
          "javascriptreact",
          "typescriptreact",
          "astro",
        },
        callback = function()
          vim.cmd("EmmetInstall")
        end,
      })
    end,
  }),
}
