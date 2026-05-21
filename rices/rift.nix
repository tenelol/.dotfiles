{ delib, ... }:
delib.rice {
  name = "rift";
  inherits = [ "indigo" ];

  myconfig = {
    aerospace.enable = false;
    autoraise.enable = false;
    rift.enable = true;
  };
}
