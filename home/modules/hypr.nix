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
    ../../config/hypr/hyprland.conf;

  xdg.configFile."hypr/hyprpaper.conf".source =
    ../../config/hypr/hyprpaper.conf;
}
