{
  delib,
  inputs,
  pkgs,
  ...
}:
let
  commonHomeManagerModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hm-backup";
    home-manager.extraSpecialArgs = { inherit inputs; };
    home-manager.sharedModules = [
      inputs.spicetify-nix.homeManagerModules.spicetify
    ];

    environment.systemPackages = [
      pkgs.home-manager
    ];
  };
in
delib.module {
  name = "home-manager";

  myconfig.always = {
    args.shared.hm = inputs.home-manager.lib.hm;
  };

  nixos.always = commonHomeManagerModule;
  darwin.always = commonHomeManagerModule;
}
