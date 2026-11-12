{ delib, hostTraits, ... }:
delib.module {
  name = "fcitx5";

  options = delib.singleEnableOption hostTraits.linuxDesktop;

  home.ifEnabled.xdg.configFile."fcitx5/conf/classicui.conf".source = ./files/classicui.conf;
}
