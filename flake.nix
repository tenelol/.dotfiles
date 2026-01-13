{
  description = "my NixOS (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    nix-hazkey.url = "github:aster-void/nix-hazkey";
    nix-hazkey.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, nix-hazkey, ... }:
  let
    system = "x86_64-linux";

    mkHost = hostPath: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self nixpkgs home-manager zen-browser nix-hazkey; };
      modules = [
        hostPath
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inputs = {
              inherit zen-browser;
            };
          };
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
      nixos-server = mkHost ./hosts/nixos-server/configuration.nix;
    };
  };
}
