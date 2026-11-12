{ delib, ... }:
delib.host {
  name = "nvidia-desktop";
  type = "desktop";
  system = "x86_64-linux";
  features = [ "fullDesktop" ];

  rice = "niri";

  myconfig = {
    boot.efiLimine = true;
    nixbuild.enable = true;
    nixos.desktop.networkBackend = "dhcpcd-resolved";
    nixos.steam.enable = true;
    minecraft.enable = true;
  };

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
