{
  delib,
  hostTraits,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  brewCask = pkgs.callPackage ../../packages/brew-cask.nix { };
  apps = builtins.fromJSON (builtins.readFile ./files/apps.json);
  selected = apps.base ++ lib.optionals host.fullDesktopFeatured apps.fullDesktop ++ apps.binaries;
  packages = lib.listToAttrs (
    map (app: {
      inherit (app) name;
      value = brewCask (
        builtins.removeAttrs app [ "name" ]
        // {
          cask = pkgs.brewCasks.${app.name};
        }
      );
    }) selected
  );
  fontPackages = map (
    font: brewCask (builtins.removeAttrs font [ "name" ] // { cask = pkgs.brewCasks.${font.name}; })
  ) apps.fonts;
in
delib.module {
  name = "brew-casks";

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.always.nixpkgs.overlays = [ inputs.brew-nix.overlays.default ];
  darwin.ifEnabled.fonts.packages = fontPackages;

  home.ifEnabled = {
    home.packages =
      lib.attrValues packages
      ++ lib.concatMap (package: lib.optional (package ? completionPackage) package.completionPackage) (
        lib.attrValues packages
      );
    # ~/.local/bin precedes Homebrew in this repository's session PATH.
    home.file = lib.listToAttrs (
      lib.concatMap (
        app:
        map (command: {
          name = ".local/bin/${command}";
          value.source = "${packages.${app.name}}/bin/${command}";
        }) (lib.attrNames (app.cli or { }))
      ) selected
    );
  };
}
