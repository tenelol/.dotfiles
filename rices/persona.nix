{ delib, ... }:
delib.rice {
  name = "persona";

  myconfig = {
    hyprland.enable = true;
    niri.enable = false;
    persona-quickshell.enable = false;
    waybar.enable = false;
    theme = {
      wallpaper = "rift.png";
      ghostty = {
        foreground = "d8dee9";
        background = "111111";
        backgroundBlur = 0;
        readabilityScrim = 0.14;
        cursor = "d8dee9";
        selectionForeground = "f2f4f8";
        selectionBackground = "30363d";
      };
    };
  };
}
