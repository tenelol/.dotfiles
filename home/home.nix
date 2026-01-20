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
      acpi
      alsa-utils
      brightnessctl
      playerctl
      pulseaudio
      iw
      iproute2
      iputils
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
      noto-fonts
      noto-fonts-color-emoji
      pkgs.nerd-fonts.caskaydia-cove
      pkgs.material-symbols
    ];

  home.file = lib.optionalAttrs (!isServer) {
    ".local/bin/emoji-walker" = {
      source = ../config/scripts/emoji-walker;
      executable = true;
    };
    ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
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

  programs.caelestia = lib.mkIf (!isServer) {
    enable = true;
    package = inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli;
    systemd.enable = false;
    cli.enable = true;
  };

  xdg.configFile = lib.optionalAttrs (!isServer) {
    "quickshell/caelestia".source = ../config/caelestia;
    "caelestia/shell.json".text = ''
      {
        "paths": {
          "wallpaperDir": "/home/tener/.dotfiles/img",
          "sessionGif": "root:/assets/kurukuru.gif",
          "mediaGif": "root:/assets/bongocat.gif"
        }
      }
    '';
    "caelestia/cli.json".text = "{}";
    # Hide fcitx5 tray / layout indicator (classicui)
    "fcitx5/conf/classicui.conf".text = ''
      [ClassicUI]
      UseTrayIcon=False
      ShowLayoutNameInIcon=False
      PreferTextIcon=False
    '';
  };
}
