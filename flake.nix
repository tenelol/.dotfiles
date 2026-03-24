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

      filterConfigurations =
        predicate: configurations:
        lib.filterAttrs (
          _: configuration: predicate configuration.pkgs.stdenv.hostPlatform.system
        ) configurations;

      filterConfigurationsByPattern =
        systemPattern: configurations:
        filterConfigurations (system: builtins.match systemPattern system != null) configurations;

      filterConfigurationsBySystem =
        system: configurations:
        filterConfigurations (configurationSystem: configurationSystem == system) configurations;

      mkChecks =
        configurations:
        lib.mapAttrs (
          name: configuration:
          configuration.pkgs.writeText "eval-${name}" (
            builtins.unsafeDiscardStringContext configuration.config.system.build.toplevel.drvPath + "\n"
          )
        ) configurations;

      # denix currently returns every host in both outputs, so filter them to keep
      # the public flake interface aligned with the actual target platform.
      nixosConfigurations = filterConfigurationsByPattern ".*-linux" (mkConfigurations "nixos");
      darwinConfigurations = filterConfigurationsByPattern ".*-darwin" (mkConfigurations "darwin");
      allConfigurations = nixosConfigurations // darwinConfigurations;
      supportedSystems = lib.unique (
        map (configuration: configuration.pkgs.stdenv.hostPlatform.system) (
          builtins.attrValues allConfigurations
        )
      );
    in
    {
      inherit nixosConfigurations darwinConfigurations;

      checks = lib.genAttrs supportedSystems (
        system: mkChecks (filterConfigurationsBySystem system allConfigurations)
      );

      formatter = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
