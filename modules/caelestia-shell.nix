{ delib, host, pkgs, inputs, lib, ... }:
let
  caelestiaShellPackage = import ../packages/caelestia-shell.nix {
    inherit inputs pkgs lib;
  };
in
delib.module {
  name = "caelestia-shell";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.packages = [
      (caelestiaShellPackage.override { withCli = true; })
    ];
  };
}
