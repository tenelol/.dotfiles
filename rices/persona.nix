{ delib, ... }:
delib.rice {
  name = "persona";

  myconfig = {
    hyprland.enable = true;
    niri.enable = false;
    persona-quickshell.enable = false;
    waybar.enable = false;
    theme.wallpaper = "rift.png";
  };
}
