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
    programs.caelestia = {
      enable = true;
      package = caelestiaShellPackage.override { withCli = true; };
      systemd.enable = false;
      cli.enable = true;
    };
  };
}
