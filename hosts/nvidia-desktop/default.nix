{ delib, ... }:
delib.host {
  name = "nvidia-desktop";
  type = "desktop";
  system = "x86_64-linux";

  myconfig.boot.efiSystemdBoot = true;
  myconfig.rice = "indigo";
  myconfig.nixos.desktop.networkBackend = "iwd-networkd";

  nixos.imports = [
    ./hardware-configuration.nix
  ];
}
