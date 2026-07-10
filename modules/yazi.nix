{
  delib,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "yazi";

  home.always = {
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.yazi ];
    xdg.configFile."yazi".source = ../config/yazi;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "yazi.desktop" ];
        "application/x-gnome-saved-search" = [ "yazi.desktop" ];
      };
    };

    xdg.configFile."mimeapps.list".force = true;
    xdg.dataFile."applications/mimeapps.list".force = true;
  };
}
