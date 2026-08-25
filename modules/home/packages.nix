{
  delib,
  host,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  isServer = host.isServer or false;
  homePackages = import ../../lib/home-packages.nix {
    inherit pkgs lib inputs;
  };
in
delib.module {
  name = "home-packages";

  home.always.home.packages = homePackages.forHost {
    inherit isServer;
    fullDesktop = host.fullDesktopFeatured;
  };
}
