{ delib, ... }:
delib.host {
  name = "nixos";
  type = "laptop";
  system = "x86_64-linux";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
