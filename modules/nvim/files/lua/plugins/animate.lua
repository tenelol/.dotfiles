local plugin = require("nix-plugin")

return {
  plugin.spec("mini-animate", {
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")
      local timing = animate.gen_timing.linear({ duration = 150, unit = "total" })

      animate.setup({
        cursor = { timing = timing },
        scroll = {
          -- Keep small scrolls responsive when holding a movement key.
          timing = function(_, steps)
            return math.min(150 / steps, 10)
          end,
        },
        resize = { timing = timing },
        open = { timing = timing },
        close = { timing = timing },
      })
    end,
  }),
}
