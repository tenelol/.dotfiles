{ delib, ... }:
delib.module {
  name = "zellij";

  home.always = {
    xdg.configFile."zellij/config.kdl".source = ../config/zellij/config.kdl;
    xdg.configFile."zellij/layouts".source = ../config/zellij/layouts;
  };
}
