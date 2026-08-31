{ delib, ... }:
delib.rice {
  name = "hyprland";

  myconfig = {
    hyprland.enable = true;
    niri.enable = false;
    theme.wallpaper = "hyprland.png";
  };
}
