{ config, lib, pkgs, ... }:
let
  isDesktop = (config.networking.hostName or "") == "nvidia-desktop";
in
{
  config = lib.mkIf isDesktop {
    # ここにデスクトップだけの差分を書く
    home.packages = with pkgs; [ /* ... */ ];
  };
}

