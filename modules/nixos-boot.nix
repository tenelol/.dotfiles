{
  delib,
  host,
  lib,
  ...
}:
delib.module {
  name = "boot";

  options =
    with delib;
    moduleOptions {
      efiSystemdBoot = boolOption false;
    };

  nixos.always =
    { myconfig, ... }:
    lib.mkIf (builtins.match ".*-linux" host.system != null && myconfig.boot.efiSystemdBoot) {
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      boot.loader.efi.canTouchEfiVariables = true;
    };
}
