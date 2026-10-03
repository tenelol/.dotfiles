{
  delib,
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
    { cfg, ... }:
    lib.mkIf cfg.efiLimine {
      boot.loader = {
        limine = {
          enable = true;
          style = {
            wallpapers = [ ../../rices/wallpapers/rift.png ];
            wallpaperStyle = "centered";
          };
        };
        efi.canTouchEfiVariables = true;
      };
    };
}
