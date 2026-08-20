{ delib, ... }:
delib.host {
  name = "adguard-home";
  type = "server";
  system = "x86_64-linux";

  rice = "indigo";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
