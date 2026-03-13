{ delib, host, pkgs, inputs, lib, ... }:
let
  isDesktop = host.type == "desktop";
  caelestiaShellPackage = import ../packages/caelestia-shell.nix {
    inherit inputs pkgs lib;
  };
in
delib.module {
  name = "caelestia-shell";

  options = delib.singleEnableOption isDesktop;

  home.ifEnabled = {
    home.packages = [
      (caelestiaShellPackage.override { withCli = true; })
    ];
  };
}
