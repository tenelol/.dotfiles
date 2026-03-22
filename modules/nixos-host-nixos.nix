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
    # Keep the laptop on the default DHCP backend. The generated hardware
    # config still carries useDHCP, so forcing networkd here enables both.
    networking.useNetworkd = lib.mkForce false;
    # Tailscale's MagicDNS integrates more reliably with systemd-resolved than
    # the current resolvconf-only path used by iwd on this host.
    services.resolved.enable = true;
    networking.resolvconf.enable = lib.mkForce false;

    # Keep the laptop on the regular kernel track; unstable+latest is more likely
    # to regress power management and fan behavior on this host.
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

    services.power-profiles-daemon.enable = true;
  };
}
