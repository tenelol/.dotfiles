{
  delib,
  hostTraits,
  inputs,
  pkgs,
  ...
}:
let
  brewCask = pkgs.callPackage ../../packages/brew-cask.nix { };
in
delib.scopedModule {
  name = "brew-casks";
  scope = hostTraits.darwinDesktop;

  options = delib.singleEnableOption hostTraits.darwinDesktop;

  darwin.always.nixpkgs.overlays = [ inputs.brew-nix.overlays.default ];

  home.ifEnabled.home.packages = [
    (brewCask pkgs.brewCasks.insomnia)
    (brewCask pkgs.brewCasks.notion)
  ];
}
