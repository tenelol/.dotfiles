{ delib, ... }:
delib.host {
  name = "nixos";
  type = "laptop";
  system = "x86_64-linux";

  myconfig.boot.efiSystemdBoot = true;
  myconfig.rice = "indigo";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
