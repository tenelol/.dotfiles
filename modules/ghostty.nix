{ delib, host, ... }:
delib.module {
  name = "ghostty";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."ghostty/config".source = ../config/ghostty/config;
  };
}
