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
              hosts.features.features = [ "fullDesktop" ];
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
      linuxCheckTargets = [
        "nixos"
        "nvidia-desktop"
        "nixos-server"
        "wsl"
      ];
      darwinCheckTargets = [
        "macbook-rift"
        "macbook-aerospace"
        "macbook-mac"
      ];
      # Keep every rice buildable, but avoid rechecking generated variants after
      # Nix has already validated the public NixOS configurations.
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

      devShells = lib.genAttrs supportedSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.curl
              pkgs.git
              pkgs.nodejs_24
            ];

            shellHook = ''
              if [ -t 1 ]; then
                export DOTFILES_EXPLORER_PORT="''${DOTFILES_EXPLORER_PORT:-43110}"
                explorer_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
                explorer_url="http://127.0.0.1:$DOTFILES_EXPLORER_PORT"
                explorer_log="''${TMPDIR:-/tmp}/dotfiles-explorer-$DOTFILES_EXPLORER_PORT.log"

                if ! ${pkgs.curl}/bin/curl --silent --fail "$explorer_url/api/health" >/dev/null 2>&1; then
                  DOTFILES_REPO_ROOT="$explorer_root" \
                    ${pkgs.nodejs_24}/bin/node "$explorer_root/tools/dotfiles-explorer/server.mjs" \
                    >"$explorer_log" 2>&1 &
                  export DOTFILES_EXPLORER_PID=$!

                  trap 'kill "$DOTFILES_EXPLORER_PID" >/dev/null 2>&1 || true' EXIT

                  explorer_attempt=0
                  while ! ${pkgs.curl}/bin/curl --silent --fail "$explorer_url/api/health" >/dev/null 2>&1; do
                    explorer_attempt=$((explorer_attempt + 1))
                    if [ "$explorer_attempt" -ge 30 ]; then
                      echo "dotfiles explorer failed to start; see $explorer_log" >&2
                      break
                    fi
                    sleep 0.1
                  done
                fi

                echo "dotfiles explorer: $explorer_url"
                if [ "''${DOTFILES_EXPLORER_NO_OPEN:-0}" != "1" ]; then
                  if command -v open >/dev/null 2>&1; then
                    open "$explorer_url" >/dev/null 2>&1
                  elif command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "$explorer_url" >/dev/null 2>&1
                  fi
                fi
              fi
            '';
          };
        }
      );

      formatter = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
