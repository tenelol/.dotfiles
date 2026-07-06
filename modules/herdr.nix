{ delib, host, ... }:
delib.module {
  name = "herdr";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."herdr/config.toml" = {
      force = true;
      source = ../config/herdr/config.toml;
    };
  };
}
