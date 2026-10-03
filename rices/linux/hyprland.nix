{ delib, ... }:
delib.rice {
  name = "hyprland";

  myconfig = {
    desktop.linux.windowManager = "hyprland";
    theme.wallpaper = "hyprland.png";
  };
}
