{ config, pkgs, ... }:
{
  xdg.configFiles."kitty/kitty.conf".source = ../../kitty;

  home.packages = with pkgs; [
    kitty
  ];

}
