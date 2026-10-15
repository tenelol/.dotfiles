local plugin = require("nix-plugin")

return {
  plugin.spec("mini-animate", {
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")
      local ghostty_cursor = vim.fn.has("macunix") == 1
        and (vim.env.TERM_PROGRAM == "ghostty" or vim.env.TERM == "xterm-ghostty")
      local timing = animate.gen_timing.quadratic({ duration = 160, unit = "total", easing = "out" })
      local scroll_timing = animate.gen_timing.quadratic({ duration = 200, unit = "total", easing = "out" })

      animate.setup({
        cursor = {
          -- The macOS Ghostty profile already animates the cursor with shaders.
          enable = not ghostty_cursor,
          timing = animate.gen_timing.quadratic({ duration = 120, unit = "total", easing = "out" }),
          path = animate.gen_path.line({
            max_output_steps = 30,
            predicate = function(destination)
              return math.abs(destination[1]) > 1 or math.abs(destination[2]) > 3
            end,
          }),
        },
        scroll = {
          -- Keep small scrolls responsive when holding a movement key.
          timing = function(step, steps)
            return math.min(scroll_timing(step, steps), 10)
          end,
        },
        resize = {
          timing = timing,
          subresize = animate.gen_subresize.equal({
            predicate = function(sizes)
              for win in pairs(sizes) do
                if vim.api.nvim_win_is_valid(win) and vim.w[win].dotfiles_panel_animation then
                  return false
                end
              end
              return true
            end,
          }),
        },
        -- New and focused windows land a lock-on from core.targets instead of a wipe.
        open = { enable = false },
        close = { enable = false },
      })
    end,
  }),
}
