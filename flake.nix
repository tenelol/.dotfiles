{
  description = "my NixOS (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";

    mkHost = hostPath: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        hostPath
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.tener = import ./home/home.nix;

          environment.systemPackages = with pkgs; [
            home-manager
          ];
        })
      ];
    };
  in
  {
    nixosConfigurations = {
      nixos = mkHost ./hosts/nixos/configuration.nix;
      nvidia-desktop = mkHost ./hosts/nvidia-desktop/configuration.nix;
    };
  };
}

