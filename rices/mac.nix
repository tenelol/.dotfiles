{ delib, ... }:
delib.rice {
  name = "mac";

  myconfig = {
    aerospace.enable = false;
    autoraise.enable = false;
    jankyborders.enable = false;
    rift.enable = false;
    theme.wallpaper = "wallpaper.png";
  };
}
