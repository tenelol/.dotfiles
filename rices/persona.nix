{ delib, ... }:
delib.rice {
  name = "persona";

  myconfig = {
    persona-quickshell.enable = true;
    waybar.enable = false;
    theme.wallpaper = "wallpaper.png";
  };
}
