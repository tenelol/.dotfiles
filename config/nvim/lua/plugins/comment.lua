local plugin = require("nix-plugin")

return {
  plugin.spec("comment-nvim", {
    lazy = false,
    config = function()
      local comment_ft = require("Comment.ft")
      local comment_utils = require("Comment.utils")
      local unpack_fn = table.unpack or unpack
      local ts_like_filetypes = {
        javascript = true,
        javascriptreact = true,
        typescript = true,
        typescriptreact = true,
      }

      comment_utils.catch = function(fn, ...)
        local args = { ... }
        xpcall(fn, function(err)
          local msg
          if type(err) == "table" then
            msg = err.msg or err.message or vim.inspect(err)
          else
            msg = tostring(err)
          end
          vim.notify(("[Comment.nvim] %s"):format(msg), vim.log.levels.WARN)
        end, unpack_fn(args))
      end
      vim.g.comment_nvim_catch_patched = true

      require("Comment").setup({
        -- Prefer the filetype table for JS/TS buffers to avoid treesitter lookup issues.
        pre_hook = function(ctx)
          local filetype = vim.bo.filetype
          if ts_like_filetypes[filetype] then
            return comment_ft.get(filetype, ctx.ctype) or vim.bo.commentstring
          end
        end,
      })
    end,
  }),
}
