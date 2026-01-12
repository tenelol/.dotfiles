{ pkgs, lib, inputs, ... }:
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
    gh waybar parted ghostty swww
    wofi floorp-bin sqlitebrowser
    eza bat walker tre-command imv ripgrep
    unicode-emoji wtype obsidian vesktop
  ];

  home.file.".local/bin/emoji-walker" = {
    source = ../config/scripts/emoji-walker;
    executable = true;
  };

  imports = [
    ./modules/shell/fish.nix
    ./modules/ghostty.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ./modules/hypr.nix
    ./modules/waybar.nix
    ./modules/niri.nix

    ../hosts/nixos/nixos.nix
    ../hosts/nvidia-desktop/nvidia-desktop.nix
  ];

  home.activation.installWalkerConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -e "$HOME/.config/walker" ]; then
      $DRY_RUN_CMD rm -rf "$HOME/.config/walker"
    fi
    $DRY_RUN_CMD mkdir -p "$HOME/.config/walker"
    $DRY_RUN_CMD cp -r ${../config/walker}/. "$HOME/.config/walker/"
    $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/walker"
  '';
}
