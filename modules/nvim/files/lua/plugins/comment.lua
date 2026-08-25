local plugin = require("nix-plugin")

return {
  plugin.spec("comment-nvim", {
    lazy = false,
    config = function()
      local comment_ft = require("Comment.ft")
      local comment_utils = require("Comment.utils")
      local unpack_fn = table.unpack or unpack
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
        -- Prefer filetype/native commentstring over treesitter to avoid crashes in
        -- Comment.ft.contains() on some buffers/parsers.
        pre_hook = function(ctx)
          local filetype = vim.bo.filetype
          local commentstring = comment_ft.get(filetype, ctx.ctype) or vim.bo.commentstring

          if type(commentstring) == "string" and commentstring ~= "" then
            return commentstring
          end
        end,
      })
    end,
  }),
}
