{ pkgs, ... }:
{
  home.packages = [ pkgs.yazi ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "yazi.desktop" ];
      "application/x-gnome-saved-search" = [ "yazi.desktop" ];
    };
  };

  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.configFile."yazi".source = ../../config/yazi;
}
