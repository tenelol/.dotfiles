{
  description = "my NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    hmCli = home-manager.packages.${system}.home-manager;
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixpkgs.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          environment.systemPackages = [
            hmCli
          ];
        })

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackagers = true;
          home-manager.users.tener = import ./home.nix;
        }
      ];
    };
  };
}
