{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  desktop = import ../lib/nixos/desktop.nix { inherit lib pkgs; };
in
delib.module {
  name = "nixos.desktop";

  options =
    with delib;
    moduleOptions {
      enable = boolOption (!host.isServer && builtins.match ".*-linux" host.system != null);
      networkBackend = strOption "iwd-networkd";
    };

  nixos.ifEnabled = { myconfig, ... }: desktop.mkConfig myconfig.nixos.desktop.networkBackend;
}
