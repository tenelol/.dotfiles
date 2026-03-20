{
  delib,
  host,
  pkgs,
  lib,
  ...
}:
let
  localExtensions = import ../packages/vscode-extensions.nix { inherit pkgs lib; };
in
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

        extensions =
          with pkgs.vscode-extensions;
          [
            esbenp.prettier-vscode
            ritwickdey.liveserver
            asvetliakov.vscode-neovim
          ]
          ++ builtins.filter (extension: extension != null) (builtins.attrValues localExtensions);
      };
    };
  };
}
