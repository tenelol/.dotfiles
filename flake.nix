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

    gijiroku.url = "git+ssh://git@github.com/tenelol/gijiroku.git";
    gijiroku.flake = false;
  };

  outputs =
    { denix, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      isLinuxSystem = system: lib.hasSuffix "-linux" system;
      isDarwinSystem = system: lib.hasSuffix "-darwin" system;
      hostDirectories = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts);
      hardwareConfigurationExcludes = lib.concatLists (
        lib.mapAttrsToList (
          name: _:
          let
            hardwareConfiguration = ./hosts + "/${name}/hardware-configuration.nix";
          in
          lib.optional (builtins.pathExists hardwareConfiguration) hardwareConfiguration
        ) hostDirectories
      );
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
            ./rices
          ];
          # Keep generated hardware configs out of denix auto-discovery without
          # needing to update this list every time a new NixOS host is added.
          exclude = hardwareConfigurationExcludes;

          extensions = with denix.lib.extensions; [
            args
            (base.withConfig {
              args.enable = true;
              rices.enable = true;
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

      filterConfigurationsBySystem =
        system: configurations:
        filterConfigurations (configurationSystem: configurationSystem == system) configurations;

      mkEvalChecks =
        configurations:
        lib.mapAttrs (
          name: configuration:
          configuration.pkgs.writeText "eval-${name}" (
            builtins.unsafeDiscardStringContext configuration.config.system.build.toplevel.drvPath + "\n"
          )
        ) configurations;

      mkLinuxBuildChecks =
        configurations:
        lib.mapAttrs' (
          name: configuration: lib.nameValuePair "build-${name}" configuration.config.system.build.toplevel
        ) configurations;

      # denix currently returns every host in both outputs, so filter them to keep
      # the public flake interface aligned with the actual target platform.
      nixosConfigurations = filterConfigurations isLinuxSystem (mkConfigurations "nixos");
      darwinConfigurations = filterConfigurations isDarwinSystem (mkConfigurations "darwin");
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
        system:
        let
          systemConfigurations = filterConfigurationsBySystem system allConfigurations;
          linuxSystemConfigurations = filterConfigurationsBySystem system nixosConfigurations;
        in
        mkEvalChecks systemConfigurations
        // lib.optionalAttrs (isLinuxSystem system) (mkLinuxBuildChecks linuxSystemConfigurations)
      );

      formatter = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
