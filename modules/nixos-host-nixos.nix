{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.host.nixos";

  options = delib.singleEnableOption (host.name == "nixos");

  nixos.ifEnabled = {
    networking.hostName = "nixos";
    networking.nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    # Keep the laptop on the default DHCP backend instead of the desktop-wide
    # networkd+iwd L3 stack.
    networking.useNetworkd = lib.mkForce false;
    networking.wireless.iwd.settings.General.EnableNetworkConfiguration = lib.mkForce false;
    # Keep DNS on systemd-resolved for Tailscale MagicDNS while dhcpcd owns
    # address assignment on this host.
    services.resolved.enable = true;

    # Keep the laptop on the regular kernel track; unstable+latest is more likely
    # to regress power management and fan behavior on this host.
    boot.kernelPackages = pkgs.linuxPackages;

    services.power-profiles-daemon.enable = true;
  };
}
