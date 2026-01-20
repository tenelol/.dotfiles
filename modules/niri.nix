{ delib, host, ... }:
delib.module {
  name = "niri";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."niri".source = ../config/niri;
  };
}
