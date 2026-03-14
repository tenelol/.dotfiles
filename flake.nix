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

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    nix-hazkey.url = "github:aster-void/nix-hazkey";
    nix-hazkey.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { denix, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      profile = {
        username = "tener";
        gitName = "tenelol";
        gitEmail = "tenelol@tenelol.dev";
        sshPublicKey = ./keys/tener.pub;
      };
      mkConfigurations =
        moduleSystem:
        denix.lib.configurations {
          inherit moduleSystem;
          homeManagerUser = profile.username;

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
            inherit profile;
          };
        };

      filterConfigurationsBySystem =
        systemPattern: configurations:
        lib.filterAttrs (
          _: configuration: builtins.match systemPattern configuration.pkgs.stdenv.hostPlatform.system != null
        ) configurations;

      mkChecks =
        configurations:
        lib.mapAttrs (_: configuration: configuration.config.system.build.toplevel) configurations;

      # denix currently returns every host in both outputs, so filter them to keep
      # the public flake interface aligned with the actual target platform.
      nixosConfigurations = filterConfigurationsBySystem ".*-linux" (mkConfigurations "nixos");
      darwinConfigurations = filterConfigurationsBySystem ".*-darwin" (mkConfigurations "darwin");
    in
    {
      inherit nixosConfigurations darwinConfigurations;

      checks = {
        x86_64-linux = mkChecks (filterConfigurationsBySystem "x86_64-linux" nixosConfigurations);
        aarch64-darwin = mkChecks (filterConfigurationsBySystem "aarch64-darwin" darwinConfigurations);
        x86_64-darwin = mkChecks (filterConfigurationsBySystem "x86_64-darwin" darwinConfigurations);
      };

      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
        x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt;
      };
    };
}
