{ config, pkgs, lib, inputs, ... }:
let
  isServer =
    if config ? myconfig && config.myconfig ? host && config.myconfig.host ? isServer then
      config.myconfig.host.isServer
    else
      false;
in
{
  home.username = "tener";
  home.homeDirectory = "/home/tener";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;
  home.sessionPath = [
    "/home/tener/.npm-global/bin"
    "/home/tener/.local/bin"
  ];
  home.packages =
    with pkgs;
    [
      gh
      parted
      zellij
      eza
      bat
      tre-command
      ripgrep
      prettierd
      nodePackages.prettier
    ]
    ++ lib.optionals (!isServer) [
      waybar
      eww
      acpi
      alsa-utils
      brightnessctl
      iproute2
      iputils
      wireless-tools
      ghostty
      swww
      wofi
      floorp-bin
      sqlitebrowser
      walker
      imv
      unicode-emoji
      wtype
      obsidian
      vesktop
      libreoffice
      spotify
      zathura
    ];

  home.file = lib.optionalAttrs (!isServer) {
    ".local/bin/emoji-walker" = {
      source = ../config/scripts/emoji-walker;
      executable = true;
    };
  };

  home.activation = lib.optionalAttrs (!isServer) {
    installWalkerConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.config/walker" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.config/walker"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/walker"
      $DRY_RUN_CMD cp -r ${../config/walker}/. "$HOME/.config/walker/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/walker"
    '';
  };
}
