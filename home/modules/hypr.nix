{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    hyprland brightnessctl
    grim
    slurp
    wl-clipboard
  ];

  xdg.configFile."hypr/hyprland.conf".source = 
    ../../config/hypr/hyprland.conf;

}
