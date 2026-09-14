{ delib, host, ... }:
delib.module {
  name = "fontconfig";

  options = delib.singleEnableOption (!(host.isServer or false));

  home.ifEnabled.home.file.".config/fontconfig/fonts.conf".source = ./files/fonts.conf;
}
