{ delib, ... }:
delib.rice {
  name = "aerospace";

  myconfig = {
    aerospace.enable = true;
    autoraise.enable = true;
    rift.enable = false;
    theme = {
      wallpaper = "wallpaper.png";
      sketchybar = {
        glassBg = "0x2a07111f";
        glassBorder = "0x387dd3fc";
        text = "0xffedf6ff";
        textDim = "0xa8b8d8ff";
        textMuted = "0xcfcae7ff";
        textStrong = "0xffffffff";
        accent = "0xff7dd3fc";
      };
      ghostty = {
        foreground = "dbeafe";
        background = "101827";
        cursor = "7dd3fc";
        selectionForeground = "e0f2fe";
        selectionBackground = "1e3a5f";
      };
      jankyborders = {
        activeColor = "gradient(top_left=0xff0f172a,bottom_right=0xff7dd3fc)";
        inactiveColor = "gradient(top_left=0xff111827,bottom_right=0xff93a4b8)";
        backgroundColor = "0x00000000";
      };
    };
  };
}
