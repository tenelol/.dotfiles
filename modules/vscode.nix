{
  delib,
  host,
  pkgs,
  lib,
  ...
}:
delib.module {
  name = "vscode";

  home.always = lib.mkIf (!host.isServer) {
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
