{
  delib,
  hostTraits,
  host,
  inputs,
  pkgs,
  ...
}:
let
  brewCask = pkgs.callPackage ../../packages/brew-cask.nix { };
  apps = builtins.fromJSON (builtins.readFile ./files/apps.json);
  selected = apps.base ++ pkgs.lib.optionals host.fullDesktopFeatured apps.fullDesktop;
  packages = pkgs.lib.listToAttrs (
    map (app: {
      name = app.name;
      value = brewCask (builtins.removeAttrs app [ "name" ] // { cask = pkgs.brewCasks.${app.name}; });
    }) selected
  );
in
delib.scopedModule {
  name = "brew-casks";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.always.nixpkgs.overlays = [ inputs.brew-nix.overlays.default ];

  home.ifEnabled = {
    home.packages =
      pkgs.lib.attrValues packages
      ++ pkgs.lib.concatMap (
        package: pkgs.lib.optional (package ? completionPackage) package.completionPackage
      ) (pkgs.lib.attrValues packages);
    # ~/.local/bin precedes Homebrew in this repository's session PATH.
    home.file = pkgs.lib.listToAttrs (
      pkgs.lib.concatMap (
        app:
        map (command: {
          name = ".local/bin/${command}";
          value.source = "${packages.${app.name}}/bin/${command}";
        }) (pkgs.lib.attrNames (app.cli or { }))
      ) selected
    );
  };
}
