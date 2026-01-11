{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  zenPackages = inputs.zen-browser.packages.${system};
in
{
  home.packages = [
    zenPackages.default
  ];
}
