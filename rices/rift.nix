{ delib, ... }:
delib.rice {
  name = "rift";

  myconfig = {
    aerospace.enable = false;
    autoraise.enable = false;
    rift.enable = true;
    theme = {
      wallpaper = "rift.png";
      ghostty = {
        backgroundBlur = 96;
        readabilityScrim = 0.42;
      };
    };
  };
}
