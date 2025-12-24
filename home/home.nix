{ pkgs, ... }:
{
  home.username = "tener";
  home.homeDirectory = "/home/tener";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;
  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  home.packages = with pkgs; [
    gh waybar parted
    wofi floorp-bin sqlitebrowser
    eza bat fuzzel tre-command imv ripgrep
  ];

  imports = [
    ./modules/shell/fish.nix
    ./modules/kitty.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ./modules/hypr.nix
    ./modules/waybar.nix
    ./modules/niri.nix

    ../hosts/nixos/nixos.nix
    ../hosts/nvidia-desktop/nvidia-desktop.nix
  ];
}
