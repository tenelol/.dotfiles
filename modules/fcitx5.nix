{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "fcitx5";

  options = delib.singleEnableOption (pkgs.stdenv.hostPlatform.isLinux && !(host.isServer or false));

  home.ifEnabled.xdg.configFile."fcitx5/conf/classicui.conf".source = ./fcitx5/files/classicui.conf;
}
