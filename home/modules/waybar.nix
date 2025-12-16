{ config, pkgs, ... }:
{
  xdg.configFile."waybar".source = ../../waybar;

  home.packages = with pkgs; [
    waybar
  ];
}
