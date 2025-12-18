{ config, pkgs, lib, ... }:

let
  host = config.networking.hostName or "";
in
{
  home.username = "tener";
  home.homeDirectory = "/home/tener";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.packages = with pkgs; [
    kitty gh waybar parted
    wofi floorp-bin sqlitebrowser
    eza bat fuzzel tre-command imv ripgrep
    incus zstd
  ];

  imports =
    [
      ./modules/shell/fish.nix
      ./modules/kitty.nix
      ./modules/git.nix
      ./modules/nvim.nix
      ./modules/hypr.nix
      ./modules/waybar.nix
    ]
    ++ lib.optionals (host == "nvidia-desktop") [
      ./hosts/nvidia-desktop/niri.nix
    ]
    ++ lib.optionals (host == "nixos") [
      ./hosts/nixos/niri.nix
    ];
}

