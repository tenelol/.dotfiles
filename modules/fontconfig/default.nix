{ delib, hostTraits, ... }:
delib.module {
  name = "fontconfig";

  options = delib.singleEnableOption hostTraits.desktop;

  home.ifEnabled.home.file.".config/fontconfig/fonts.conf".source = ./files/fonts.conf;
}
