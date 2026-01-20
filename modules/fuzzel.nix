{ delib, host, ... }:
delib.module {
  name = "fuzzel";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."fuzzel".source = ../config/fuzzel;
  };
}
