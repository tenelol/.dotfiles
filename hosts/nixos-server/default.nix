{ delib, ... }:
delib.host {
  name = "nixos-server";
  type = "server";
  system = "x86_64-linux";

  myconfig.boot.efiSystemdBoot = true;
  rice = "indigo";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
