{ delib, ... }:
delib.rice {
  name = "aerospace";
  inherits = [ "indigo" ];

  myconfig = {
    aerospace.enable = true;
    rift.enable = false;
  };
}
