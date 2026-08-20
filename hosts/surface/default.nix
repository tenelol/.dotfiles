{ delib, ... }:
delib.host {
  name = "surface";
  type = "laptop";
  system = "x86_64-linux";
  features = [ "fullDesktop" ];

  myconfig.boot.efiSystemdBoot = true;
  myconfig.nixbuild.enable = true;
  rice = "indigo";

  myconfig.nixos.desktop.networkBackend = "dhcpcd-resolved";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
