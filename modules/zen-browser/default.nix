{
  delib,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  zenPackages = inputs.zen-browser.packages.${system};
in
delib.module {
  name = "zen-browser";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      zenPackages.default
    ];

    xdg.mimeApps.defaultApplications = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      "text/html" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
    };
  };
}
