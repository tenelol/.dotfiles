{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.host.nixos";

  options = delib.singleEnableOption (host.name == "nixos");

  nixos.ifEnabled = {
    networking.hostName = "nixos";

    # Keep the laptop on the regular kernel track; unstable+latest is more likely
    # to regress power management and fan behavior on this host.
    boot.kernelPackages = pkgs.linuxPackages;

    services.power-profiles-daemon.enable = true;
  };
}
