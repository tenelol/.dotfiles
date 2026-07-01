{ delib, ... }:
delib.rice {
  name = "persona";

  myconfig = {
    hyprland.enable = true;
    niri.enable = false;
    persona-quickshell.enable = true;
    waybar.enable = false;
    theme.wallpaper = "wallpaper.png";
  };
}
