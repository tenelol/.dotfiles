{
  delib,
  host,
  hostLib,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "vscode";

  home.always = lib.mkIf (hostLib.isDesktop host) {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false;

      profiles.default = {
        userSettings = {
          "extensions.experimental.affinity" = {
            "asvetliakov.vscode-neovim" = 1;
          };
          "files.autoSave" = "afterDelay";
        };

        extensions = with pkgs.vscode-extensions; [
          esbenp.prettier-vscode
          ritwickdey.liveserver
          asvetliakov.vscode-neovim
        ];
      };
    };
  };
}
