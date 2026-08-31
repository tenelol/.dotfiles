{ delib, ... }:
delib.host {
  name = "nas";
  type = "server";
  system = "x86_64-linux";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
