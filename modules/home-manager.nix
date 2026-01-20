{ delib, inputs, pkgs, ... }:
delib.module {
  name = "home-manager";

  nixos.always = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = { inherit inputs; };

    environment.systemPackages = [
      pkgs.home-manager
    ];
  };
}
