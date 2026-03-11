{ delib, host, ... }:
delib.module {
  name = "waybar";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."waybar".source = ../config/waybar2;
  };
}
