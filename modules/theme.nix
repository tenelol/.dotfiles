{
  delib,
  host,
  lib,
  ...
}:
delib.module {
  name = "theme";

  options =
    with delib;
    moduleOptions {
      wallpaper = strOption "Indigo.png";
    };

  home.always =
    { myconfig, ... }:
    lib.mkIf (!host.isServer) {
      # Keep a stable target path so desktop components can switch rice without
      # knowing the underlying wallpaper file name.
      xdg.configFile = {
        "theme/wallpaper.png".source = ../img + "/${myconfig.theme.wallpaper}";
        "wallpapers".source = ../img;
      };
    };
}
