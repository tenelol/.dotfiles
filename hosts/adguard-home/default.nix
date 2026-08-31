{ delib, ... }:
delib.host {
  name = "adguard-home";
  type = "server";
  system = "x86_64-linux";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
