{ delib, ... }:
delib.rice {
  name = "aerospace";

  myconfig = {
    aerospace.enable = true;
    autoraise.enable = true;
    rift.enable = false;
    theme = {
      wallpaper = "aerospace.png";
      sketchybar = {
        glassBg = "0x2a07111f";
        glassBorder = "0x3886efac";
        text = "0xffecfdf5";
        textDim = "0xa8bbf7d0";
        textMuted = "0xcfa7f3d0";
        textStrong = "0xffffffff";
        accent = "0xff86efac";
      };
      ghostty = {
        foreground = "dcfce7";
        background = "0f1f17";
        backgroundBlur = 192;
        readabilityScrim = 0.58;
        leafBurst = 0.92;
        cursor = "86efac";
        selectionForeground = "ecfdf5";
        selectionBackground = "14532d";
        paletteBlue = "22c55e";
        paletteCyan = "86efac";
        paletteBrightBlue = "4ade80";
        paletteBrightCyan = "bbf7d0";
      };
      jankyborders = {
        activeColor = "gradient(top_left=0xff0f172a,bottom_right=0xff86efac)";
        inactiveColor = "gradient(top_left=0xff111827,bottom_right=0xff8aa69a)";
        backgroundColor = "0x00000000";
      };
    };
  };
}
