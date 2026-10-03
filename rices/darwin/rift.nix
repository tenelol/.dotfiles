{ delib, ... }:
delib.rice {
  name = "rift";

  myconfig = {
    desktop.darwin.windowManager = "rift";
    theme = {
      ghostty = {
        foreground = "b3bbc7";
        background = "0a0a0a";
        backgroundBlur = 96;
        readabilityScrim = 0.52;
        cursor = "5f7695";
        selectionForeground = "d8dde6";
        selectionBackground = "293448";
      };
    };
  };
}
