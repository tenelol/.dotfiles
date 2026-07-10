{
  delib,
  host,
  pkgs,
  lib,
  ...
}:
let
  vscode = import ../lib/vscode.nix { inherit pkgs; };
in
delib.module {
  name = "vscode";

  home.always = lib.mkIf (!host.isServer) {
    programs.vscode =
      vscode.program // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin { package = null; };
  };
}
