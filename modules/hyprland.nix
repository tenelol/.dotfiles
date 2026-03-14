{ delib, host, ... }:
let
  isDesktop = host.type == "desktop";
in
delib.module {
  name = "hyprland";

  options = delib.singleEnableOption isDesktop;

  home.ifEnabled = {
    xdg.configFile."hypr" = {
      source = ../config/hypr;
      recursive = true;
    };
  };
}
