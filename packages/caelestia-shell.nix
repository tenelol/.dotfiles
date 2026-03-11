{ inputs, pkgs, lib }:
let
  system = pkgs.stdenv.hostPlatform.system;

  app2unit = pkgs.app2unit.overrideAttrs (_: rec {
    version = "1.0.3";
    src = pkgs.fetchFromGitHub {
      owner = "Vladimir-csp";
      repo = "app2unit";
      tag = "v${version}";
      hash = "sha256-7eEVjgs+8k+/NLteSBKgn4gPaPLHC+3Uzlmz6XB0930=";
    };

    # Caelestia pins app2unit 1.0.3, but newer sources renamed the variable
    # that nixpkgs patches from A2U__TERMINAL_HANDLER to TERMINAL_HANDLER.
    postFixup = ''
      substituteInPlace $out/bin/app2unit \
        --replace-fail '#!/bin/sh' '#!${lib.getExe pkgs.dash}'

      substituteInPlace $out/bin/app2unit \
        --replace-fail 'TERMINAL_HANDLER=xdg-terminal-exec' \
          'TERMINAL_HANDLER=${lib.getExe pkgs.xdg-terminal-exec}'
    '';
  });
in
pkgs.callPackage "${inputs.caelestia-shell}/nix" {
  rev =
    if inputs.caelestia-shell ? rev then
      inputs.caelestia-shell.rev
    else if inputs.caelestia-shell ? dirtyRev then
      inputs.caelestia-shell.dirtyRev
    else
      "dirty";

  stdenv = pkgs.clangStdenv;
  quickshell = inputs.caelestia-shell.inputs.quickshell.packages.${system}.default.override {
    withX11 = false;
    withI3 = false;
  };
  inherit app2unit;
  caelestia-cli = inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.default;
}
