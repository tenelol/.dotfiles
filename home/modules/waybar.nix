{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    waybar
    ];
  
  xdg.configFile."waybar".source = ../../waybar;

}
