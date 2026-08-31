{ delib, ... }:
delib.host {
  name = "nvidia-desktop";
  type = "desktop";
  system = "x86_64-linux";
  features = [ "fullDesktop" ];

  myconfig.boot.efiLimine = true;
  myconfig.nixbuild.enable = true;
  rice = "niri";

  myconfig.nixos.desktop.networkBackend = "dhcpcd-resolved";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
