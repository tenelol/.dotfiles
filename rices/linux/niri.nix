{ delib, ... }:
delib.rice {
  name = "niri";

  myconfig = {
    desktop.linux.windowManager = "niri";
  };
}
