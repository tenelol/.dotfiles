{ delib, ... }:
delib.host {
  name = "nixos-server";
  type = "server";
  system = "x86_64-linux";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
