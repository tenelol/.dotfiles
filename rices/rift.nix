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
        foreground = "b3bbc7";
        background = "11151d";
        backgroundBlur = 96;
        readabilityScrim = 0.52;
        cursor = "78b6cf";
        selectionForeground = "d8dde6";
        selectionBackground = "293448";
      };
    };
  };
}
