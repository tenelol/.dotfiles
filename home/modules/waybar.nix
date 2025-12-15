{ config, pkgs, ... }:
{
  xdg.configFile."waybar".source = ../../waybar2;

  home.packages = with pkgs; [
    waybar
  ];
}
