{ config, lib, pkgs, ... }:
let
  isLaptop = (config.networking.hostName or "") == "nixos";
in
{
  config = lib.mkIf isLaptop {
    # ここにラップトップだけの差分を書く
  };
}

