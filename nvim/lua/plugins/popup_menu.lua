local popup_menu = require("utils.popup_menu")

local table = { "Item1", "Item2", "Item3" }
local opt = {
  start_index = 1,
  relative = "cursor",
  row = 0,
  col = 0,
  width = 40,
  height = 2,
  border = "rounded",
  title = "popup_menu",
  zindex = 1,
}

popup_menu.popup_menu(table, opt, function(result)
  print(result)
end)
