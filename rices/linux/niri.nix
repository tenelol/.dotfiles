{ delib, ... }:
delib.rice {
  name = "niri";

  myconfig = {
    hyprland.enable = false;
    niri.enable = true;
  };
}
