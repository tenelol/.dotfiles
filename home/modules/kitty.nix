{ config, pkgs, ... }:
{
  xdg.configFile."kitty/kitty.conf".source = ../../config/kitty/kitty.conf;

  home.packages = with pkgs; [
    kitty
  ];

}
