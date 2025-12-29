{ config, pkgs, ... }:
{
  xdg.configFile."waybar".source = ../../config/waybar;

  home.packages = with pkgs; [
    waybar
  ];
}
