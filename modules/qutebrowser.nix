{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  qutebrowser = import ../lib/qutebrowser.nix { inherit pkgs; };
in
delib.module {
  name = "qutebrowser";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    programs.qutebrowser = qutebrowser.program;
    programs.fish.shellAbbrs = qutebrowser.fishAliases;

    xdg.mimeApps.defaultApplications = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      "text/html" = lib.mkForce [ "org.qutebrowser.qutebrowser.desktop" ];
      "application/xhtml+xml" = lib.mkForce [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/http" = lib.mkForce [ "org.qutebrowser.qutebrowser.desktop" ];
      "x-scheme-handler/https" = lib.mkForce [ "org.qutebrowser.qutebrowser.desktop" ];
    };
  };
}
