{
  delib,
  host,
  pkgs,
  lib,
  ...
}:
let
  liveSassCompiler = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    name = "live-sass";
    publisher = "glenn2223";
    version = "6.1.5";
    sha256 = "61cf63300895c7e8ef8ed1ad4c19cee9c5b7b0dafc5e6cbebecd610d2b6ebe50";
  };
in
delib.module {
  name = "vscode";

  home.always = lib.mkIf (!host.isServer) {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false;

      profiles.default = {
        userSettings = {
          "files.autoSave" = "afterDelay";
          "update.mode" = "none";
        };

        extensions = with pkgs.vscode-extensions; [
          esbenp.prettier-vscode
          ritwickdey.liveserver
          liveSassCompiler
        ];
      };
    };
  };
}
