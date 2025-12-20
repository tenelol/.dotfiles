{ config, lib, pkgs, osConfig, ... }:
let
  isDesktop = (osConfig.networking.hostName or "") == "nvidia-desktop";
in
{
  config = lib.mkIf isDesktop {
    xdg.configFile."niri/config.kdl".text = ''
      Mod+T hotkey-overlay-title="Open a Terminal: ghostty" { spawn "ghostty"; }
    '';
    home.packages = with pkgs; [ ghostty ];
  };
}

