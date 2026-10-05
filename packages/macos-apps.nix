{ pkgs, lib }:
{
  owner,
  fullDesktop,
  boringNotchEnabled,
}:
let
  catalog = builtins.fromJSON (builtins.readFile ../modules/darwin-installers/files/apps.json);
  selected = builtins.filter (
    app:
    (!(app.fullDesktop or false) || fullDesktop)
    && (!(app ? feature) || (app.feature == "boringnotch" && boringNotchEnabled))
  ) catalog;
  brewCask = pkgs.callPackage ./brew-cask.nix { };
  appSupport = pkgs.callPackage ./macos-app-support.nix { };
  extract = pkgs.callPackage ./macos-installer-source.nix { };
  shortVersion = version: lib.head (lib.splitString "," version);
  packageSources = {
    boringnotch = pkgs.callPackage ./boringnotch.nix { };
    moocs-collect = import ./moocs-collect.nix { inherit pkgs lib; };
  };

  # These three sources have an existing package or a vendor installer layout.
  # All Cask sources, including pinned bootstrap overrides, use the same path.
  sourceFor =
    spec:
    if packageSources ? ${spec.name} then
      let
        package = packageSources.${spec.name};
      in
      {
        inherit package;
        inherit (package) version;
        bundle = "Applications/${spec.app}.app";
      }
    else if spec.name == "docker-desktop" then
      let
        cask = pkgs.brewCasks.${spec.name};
        bundle = "${spec.app}.app";
        package = extract {
          name = "${spec.name}-${cask.version}";
          src = cask.src;
          artifacts = [ bundle ];
        };
      in
      {
        inherit package bundle;
        version = shortVersion cask.version;
      }
    else
      let
        base = pkgs.brewCasks.${spec.name};
        cask =
          if !(spec ? bootstrap) then
            base
          else
            base.overrideAttrs (
              _:
              {
                src = pkgs.fetchurl (builtins.removeAttrs spec.bootstrap [ "version" ]);
              }
              // lib.optionalAttrs (spec.bootstrap ? version) { inherit (spec.bootstrap) version; }
            );
        package = brewCask (
          lib.filterAttrs (
            name: _:
            builtins.elem name [
              "cli"
              "wrapCli"
              "extraFiles"
              "completions"
              "sourceHash"
            ]
          ) spec
          // {
            inherit cask;
          }
        );
      in
      {
        inherit package;
        version = shortVersion cask.version;
        bundle = "Applications/${spec.app}.app";
      };

  mkApp =
    spec:
    let
      source = sourceFor spec;
      hasIntegration = spec ? cli || spec ? extraFiles || spec ? completions;
      support = appSupport (spec // { sourcePackage = source.package; });
    in
    {
      installer = {
        inherit (spec) name bundleId teamId;
        inherit (source) version;
        inherit owner;
        kind = "app";
        app = "/Applications/${spec.app}.app";
        appVersion = source.version;
        source = "${source.package}/${source.bundle}";
        selfUpdating = true;
        running = spec.running or [ "/${spec.app}\\.app/" ];
      }
      // lib.optionalAttrs (spec.migrateBeforeNixApps or true) { migrateBeforeNixApps = true; }
      // lib.optionalAttrs (spec ? orphanHelpers) { inherit (spec) orphanHelpers; };
      packages =
        lib.optional hasIntegration support
        ++ lib.optional (source.package ? completionPackage) source.package.completionPackage;
      cliFiles = lib.mapAttrs' (
        command: _:
        lib.nameValuePair ".local/bin/${command}" {
          source = "${support}/bin/${command}";
        }
      ) (spec.cli or { });
    };
  apps = map mkApp selected;
  commands = lib.concatMap (app: builtins.attrNames (app.cli or { })) selected;
in
assert lib.length (lib.unique (map (app: app.name) catalog)) == lib.length catalog;
assert lib.length (lib.unique commands) == lib.length commands;
assert lib.all (app: !(app ? feature) || app.feature == "boringnotch") catalog;
{
  installers = map (app: app.installer) apps;
  packages = lib.concatMap (app: app.packages) apps;
  cliFiles = lib.foldl' (files: app: files // app.cliFiles) { } apps;
}
