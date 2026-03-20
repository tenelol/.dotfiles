{
  pkgs,
  lib,
}:
let
  extensionFromDir = import ./vscode-extension-from-dir.nix { inherit pkgs lib; };

  mkLocalExtension =
    {
      publisher,
      name,
      version,
      srcPath,
      meta ? { },
    }:
    if builtins.pathExists srcPath then
      extensionFromDir {
        inherit publisher name version meta;
        src = builtins.path {
          path = srcPath;
          name = "${publisher}-${name}-${version}";
        };
      }
    else
      null;
in
{
  live-sass = mkLocalExtension {
    publisher = "glenn2223";
    name = "live-sass";
    version = "6.1.5";
    srcPath = "/home/tener/.vscode/extensions/glenn2223.live-sass-6.1.5";
  };

  codex-ui-vscode-extension = mkLocalExtension {
    publisher = "harukary7518";
    name = "codex-ui-vscode-extension";
    version = "0.2.16";
    srcPath = "/home/tener/.vscode/extensions/harukary7518.codex-ui-vscode-extension-0.2.16";
  };

  chatgpt = mkLocalExtension {
    publisher = "openai";
    name = "chatgpt";
    version = "26.313.41514";
    srcPath = "/home/tener/.vscode/extensions/openai.chatgpt-26.313.41514-linux-x64";
  };
}
