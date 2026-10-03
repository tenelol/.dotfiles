local plugin = require("nix-plugin")

return {
  plugin.spec("mini-animate", {
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")
      local timing = animate.gen_timing.quadratic({ duration = 160, unit = "total", easing = "out" })
      local scroll_timing = animate.gen_timing.quadratic({ duration = 200, unit = "total", easing = "out" })

      animate.setup({
        cursor = {
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
        resize = { timing = timing },
        open = {
          timing = timing,
          winconfig = animate.gen_winconfig.wipe({ direction = "from_edge" }),
          winblend = animate.gen_winblend.linear({ from = 60, to = 100 }),
        },
        close = {
          timing = timing,
          winconfig = animate.gen_winconfig.wipe({ direction = "to_edge" }),
          winblend = animate.gen_winblend.linear({ from = 100, to = 60 }),
        },
      })
    end,
  }),
}
