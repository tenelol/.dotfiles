{ config, pkgs, ... }:

let
  # 実際の fish スクリプトは別ファイルで管理

in
{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting ""

      # 記事で書いてた LSCOLORS
      set -x LSCOLORS Gxfxcxdxbxegedabagacad
    '';
  };


}

