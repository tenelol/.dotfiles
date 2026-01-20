{ delib, host, pkgs, ... }:
delib.module {
  name = "waybar";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    xdg.configFile."waybar".source = ../config/waybar2;

    home.packages = with pkgs; [
      waybar
    ];
  };
}
