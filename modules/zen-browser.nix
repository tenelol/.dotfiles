{ delib, host, inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  zenPackages = inputs.zen-browser.packages.${system};
in
delib.module {
  name = "zen-browser";

  options = delib.singleEnableOption (!host.isServer);

  home.ifEnabled = {
    home.packages = [
      zenPackages.default
    ];

    xdg.mimeApps.defaultApplications = {
      "text/html" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
    };
  };
}
