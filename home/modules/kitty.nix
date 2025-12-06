{ config, pkgs, ... }:
{
  xdg.configFile."kitty/kitty.conf".source = ../../kitty/kitty.conf;

  home.packages = with pkgs; [
    kitty
  ];

}
