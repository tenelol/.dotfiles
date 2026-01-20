{
  description = "my NixOS (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    denix.url = "github:yunfachi/denix";
    denix.inputs.nixpkgs.follows = "nixpkgs";
    denix.inputs.home-manager.follows = "home-manager";
    denix.inputs.nix-darwin.follows = "nix-darwin";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    nix-hazkey.url = "github:aster-void/nix-hazkey";
    nix-hazkey.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { denix, ... }@inputs:
  let
    mkConfigurations =
      moduleSystem:
      denix.lib.configurations {
        inherit moduleSystem;
        homeManagerUser = "tener";

        paths = [
          ./hosts
          ./modules
        ];
        exclude = [
          ./hosts/nixos/hardware-configuration.nix
          ./hosts/nvidia-desktop/hardware-configuration.nix
          ./hosts/nixos-server/hardware-configuration.nix
        ];

        extensions = with denix.lib.extensions; [
          args
          (base.withConfig {
            args.enable = true;
            rices.enable = false;
          })
        ];

        specialArgs = {
          inherit inputs;
          nix-hazkey = inputs.nix-hazkey;
          zen-browser = inputs.zen-browser;
        };
      };
  in
  rec {
    nixosConfigurations = mkConfigurations "nixos";
    nixos = nixosConfigurations.nixos;
    nvidia-desktop = nixosConfigurations."nvidia-desktop";
    nixos-server = nixosConfigurations."nixos-server";
  };
}
