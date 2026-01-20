{ delib, host, pkgs, inputs, ... }:
delib.module {
  name = "caelestia-shell";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.packages = [
      inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli
    ];
  };
}
