{ delib, ... }:
delib.host {
  name = "surface";
  type = "laptop";
  system = "x86_64-linux";
  features = [ "fullDesktop" ];

  rice = "niri";

  myconfig = {
    boot.efiLimine = true;
    nixbuild.enable = true;
    nixos.desktop.networkBackend = "dhcpcd-resolved";
  };

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
