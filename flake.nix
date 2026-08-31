{
  description = "my NixOS (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

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

    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";

    herdr.url = "github:ogulcancelik/herdr/v0.7.1";
    herdr.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    gijiroku.url = "git+ssh://git@github.com/tenelol/gijiroku.git";
    gijiroku.flake = false;

    vault-context.url = "git+ssh://git@github.com/tenelol/vault-context.git";
    vault-context.inputs.nixpkgs.follows = "nixpkgs";
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
      linuxServerHostPaths = [
        ./hosts/adguard-home
        ./hosts/nas
        ./hosts/web-server
        ./hosts/wsl
      ];
      linuxDesktopHostPaths = [
        ./hosts/nvidia-desktop
        ./hosts/surface
      ];
      darwinHostPaths = [ ./hosts/macbook ];
      profile = {
        username = "tener";
        gitName = "tenelol";
        gitEmail = "tenelol@tenelol.dev";
        sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFkbcnmTY5/V7n2pf6Huiqdn8DPaR8qs0tHajYXQaIs";
      };
      mkConfigurations =
        {
          moduleSystem,
          hostPaths,
          ricePaths ? [ ],
        }:
        denix.lib.configurations {
          inherit moduleSystem;
          homeManagerUser = profile.username;

          paths = hostPaths ++ [ ./modules ] ++ ricePaths;
          # Keep generated hardware configs out of denix auto-discovery without
          # needing to update this list every time a new NixOS host is added.
          exclude = hardwareConfigurationExcludes;

          extensions = with denix.lib.extensions; [
            args
            (base.withConfig {
              args.enable = true;
              hosts.features.features = [ "fullDesktop" ];
              rices.enable = ricePaths != [ ];
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

      # Keep rice expansion scoped to desktop hosts; server configurations do
      # not import a rice module or expose meaningless rice variants.
      nixosServerConfigurations = mkConfigurations {
        moduleSystem = "nixos";
        hostPaths = linuxServerHostPaths;
      };
      nixosDesktopConfigurations = mkConfigurations {
        moduleSystem = "nixos";
        hostPaths = linuxDesktopHostPaths;
        ricePaths = [ ./rices/linux ];
      };
      nixosConfigurations = filterConfigurations isLinuxSystem (
        nixosServerConfigurations // nixosDesktopConfigurations
      );
      darwinConfigurations = filterConfigurations isDarwinSystem (mkConfigurations {
        moduleSystem = "darwin";
        hostPaths = darwinHostPaths;
        ricePaths = [ ./rices/darwin ];
      });
      linuxCheckTargets = [
        "adguard-home"
        "surface"
        "nvidia-desktop"
        "web-server"
        "nas"
        "wsl"
      ];
      darwinCheckTargets = [
        "macbook-rift"
        "macbook-aerospace"
        "macbook-mac"
      ];
      # Evaluate the default host configurations in CI. Rice variants remain
      # available as explicit switch targets without multiplying build checks.
      checkedNixosConfigurations = lib.getAttrs linuxCheckTargets nixosConfigurations;
      checkedConfigurations =
        checkedNixosConfigurations // lib.getAttrs darwinCheckTargets darwinConfigurations;
      supportedSystems = lib.unique (
        map (configuration: configuration.pkgs.stdenv.hostPlatform.system) (
          builtins.attrValues checkedConfigurations
        )
      );
    in
    {
      inherit nixosConfigurations darwinConfigurations;

      checks = lib.genAttrs supportedSystems (
        system:
        let
          systemConfigurations = filterConfigurationsBySystem system checkedConfigurations;
          linuxSystemConfigurations = filterConfigurationsBySystem system checkedNixosConfigurations;
        in
        mkEvalChecks systemConfigurations
        // lib.optionalAttrs (isLinuxSystem system) (mkLinuxBuildChecks linuxSystemConfigurations)
      );

      formatter = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
