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
  mkCask =
    entry: brewCask (builtins.removeAttrs entry [ "name" ] // { cask = pkgs.brewCasks.${entry.name}; });
  packages = lib.genAttrs' selected (app: lib.nameValuePair app.name (mkCask app));
  fontPackages = map mkCask apps.fonts;
  # Homebrew links this Cask binary as agy. The Nix store copy cannot replace
  # itself, so its background updater stays off; update through the pin.
  antigravityCli =
    let
      cask = pkgs.brewCasks.antigravity-cli;
    in
    pkgs.runCommand "agy-${cask.version}" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      makeWrapper ${cask}/bin/antigravity "$out/bin/agy" --set AGY_CLI_DISABLE_AUTO_UPDATE 1
    '';
in
delib.module {
  name = "brew-casks";

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.always.nixpkgs.overlays = [ inputs.brew-nix.overlays.default ];
  darwin.ifEnabled.fonts.packages = fontPackages;

  home.ifEnabled = {
    home.packages =
      let
        packageList = lib.attrValues packages;
      in
      packageList ++ lib.catAttrs "completionPackage" packageList ++ [ antigravityCli ];
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
