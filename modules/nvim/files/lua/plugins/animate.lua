local plugin = require("nix-plugin")

local function editor_window(win)
  local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
  return ft ~= "neo-tree" and ft ~= "toggleterm"
end

return {
  plugin.spec("mini-animate", {
    event = "VeryLazy",
    config = function()
      local animate = require("mini.animate")
      local timing = animate.gen_timing.quadratic({ duration = 160, unit = "total", easing = "out" })

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
          enable = false,
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
        open = {
          timing = timing,
          winconfig = animate.gen_winconfig.wipe({ direction = "from_edge", predicate = editor_window }),
          winblend = animate.gen_winblend.linear({ from = 60, to = 100 }),
        },
        close = {
          timing = timing,
          winconfig = animate.gen_winconfig.wipe({ direction = "to_edge", predicate = editor_window }),
          winblend = animate.gen_winblend.linear({ from = 100, to = 60 }),
        },
      })
    end,
  }),
}
