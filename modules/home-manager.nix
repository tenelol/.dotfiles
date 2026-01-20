{ delib, inputs, pkgs, ... }:
delib.module {
  name = "home-manager";

  myconfig.always = {
    args.shared.hm = inputs.home-manager.lib.hm;
  };

  nixos.always = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = { inherit inputs; };
    home-manager.sharedModules = [
      inputs.caelestia-shell.homeManagerModules.default
    ];

    environment.systemPackages = [
      pkgs.home-manager
    ];
  };
}
