{ delib, hostTraits, ... }:
delib.module {
  name = "herdr";

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled = {
    xdg.configFile."herdr/config.toml" = {
      force = true;
      source = ./files/config.toml;
    };
  };
}
