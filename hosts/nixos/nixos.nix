{ config, lib, pkgs, ... }:
let
  isLaptop = (config.networking.hostName or "") == "nixos";
in
{
  config = lib.mkIf isLaptop {
    home.packages = with pkgs; [ kitty incus zstd ];
  };
}

