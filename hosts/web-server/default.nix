{ delib, ... }:
delib.host {
  name = "web-server";
  type = "server";
  system = "x86_64-linux";

  rice = "indigo";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
