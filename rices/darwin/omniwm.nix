{ delib, ... }:
delib.rice {
  name = "omniwm";

  myconfig = {
    desktop.darwin.windowManager = "omniwm";
    sketchybar.enable = false;
    jankyborders.enable = false;
  };
}
