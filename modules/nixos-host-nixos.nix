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

    # Keep the laptop on the regular kernel track; unstable+latest is more likely
    # to regress power management and fan behavior on this host.
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

    services.power-profiles-daemon.enable = true;
    powerManagement.cpuFreqGovernor = "powersave";
  };
}
