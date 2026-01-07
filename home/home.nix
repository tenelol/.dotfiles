{ pkgs, ... }:
{
  home.username = "tener";
  home.homeDirectory = "/home/tener";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;
  home.sessionPath = [
    "/home/tener/.npm-global/bin"
    "/home/tener/.local/bin"
  ];



  home.packages = with pkgs; [
    gh waybar parted
    wofi floorp-bin sqlitebrowser
    eza bat fuzzel tre-command imv ripgrep
    unicode-emoji wtype obsidian
  ];

  home.file.".local/bin/emoji-fuzzel" = {
    source = ../config/scripts/emoji-fuzzel;
    executable = true;
  };

  imports = [
    ./modules/shell/fish.nix
    ./modules/kitty.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ./modules/hypr.nix
    ./modules/waybar.nix
    ./modules/fuzzel.nix
    ./modules/niri.nix

    ../hosts/nixos/nixos.nix
    ../hosts/nvidia-desktop/nvidia-desktop.nix
  ];
}
