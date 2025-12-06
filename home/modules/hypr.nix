{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    hyprland brightnessctl
    hyprpaper
    grim
    slurp
    wl-clipboard
  ];

  xdg.configFile."hypr/hyprland.conf".source = 
    ../../hypr/hyprland.conf;

  xdg.configFile."hypr/hyprpaper.conf".source =
    ../../hypr/hyprpaper.conf;
}
