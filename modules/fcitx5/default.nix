{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "fcitx5";

  options = delib.singleEnableOption (pkgs.stdenv.hostPlatform.isLinux && !host.isServer);

  home.ifEnabled.xdg.configFile."fcitx5/conf/classicui.conf".source = ./files/classicui.conf;
}
