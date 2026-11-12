{ delib, ... }:
delib.module {
  name = "boot.efiLimine";

  options = delib.singleEnableOption false;

  nixos.ifEnabled.boot.loader = {
    limine = {
      enable = true;
      style = {
        wallpapers = [ ../../rices/wallpapers/rift.png ];
        wallpaperStyle = "centered";
      };
    };
    efi.canTouchEfiVariables = true;
  };
}
