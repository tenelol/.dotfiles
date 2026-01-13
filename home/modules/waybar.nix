{ config, pkgs, ... }:
{
  xdg.configFile."waybar".source = ../../config/waybar2;

  home.packages = with pkgs; [
    waybar
  ];
}
