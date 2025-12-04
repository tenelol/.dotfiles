{ config, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;

    extraPackages = with pkgs; [
      hyprpaper
    ];
  };

  xdg.configFile."hypr/hyprland.conf".source = 
    ../../hypr/hyprland.conf;

  xdg.configFile."hypr/hyprpaper.conf".source =
    ../../hypr/hyprpaper.conf;
}
