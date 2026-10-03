{ delib, ... }:
delib.rice {
  name = "mac";

  myconfig = {
    desktop.darwin.windowManager = "native";
    jankyborders.enable = false;
  };
}
