{ delib, host, ... }:
delib.module {
  name = "eww";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."eww" = {
      source = ../config/eww;
      force = true;
    };
  };
}
