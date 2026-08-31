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
      efiLimine = boolOption false;
    };

  nixos.always =
    { myconfig, ... }:
    lib.mkIf (builtins.match ".*-linux" host.system != null && myconfig.boot.efiLimine) {
      boot.loader = {
        limine = {
          enable = true;
          style = {
            wallpapers = [ ../rices/wallpapers/rift.png ];
            wallpaperStyle = "centered";
          };
        };
        efi.canTouchEfiVariables = true;
      };
    };
}
