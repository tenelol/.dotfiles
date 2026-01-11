{ inputs, pkgs, ... }:
let
  system = pkgs.system;
  zenPackages = inputs.zen-browser.packages.${system};
in
{
  home.packages = [
    zenPackages.default
  ];
}
