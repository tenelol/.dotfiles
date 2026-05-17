{ delib, ... }:
delib.rice {
  name = "aerospace";
  inherits = [ "indigo" ];

  myconfig = {
    aerospace.enable = true;
    autoraise.enable = true;
    rift.enable = false;
  };
}
