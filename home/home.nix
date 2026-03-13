{ config, pkgs, lib, inputs, ... }:
let
  isServer =
    if config ? myconfig && config.myconfig ? host && config.myconfig.host ? isServer then
      config.myconfig.host.isServer
    else
      false;

  caelestiaShellPackage = import ../packages/caelestia-shell.nix {
    inherit inputs pkgs lib;
  };
  codexBarPackage = import ../packages/codexbar.nix {
    inherit pkgs lib;
  };
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
  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk}/lib/openjdk";
  };
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
      jdk
      prettierd
      nodePackages.prettier
    ]
    ++ lib.optionals (!isServer) [
      codexBarPackage
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
      fuzzel
      floorp-bin
      google-chrome
      sqlitebrowser
      imv
      unicode-emoji
      wtype
      obsidian
      vesktop
      slack
      libreoffice-fresh
      vscode
      zed-editor
      zathura
      antigravity-fhs
      noto-fonts
      noto-fonts-color-emoji
      pkgs.nerd-fonts.caskaydia-cove
      pkgs.material-symbols
    ];

  home.file = lib.optionalAttrs (!isServer) {
    ".local/bin/emoji-fuzzel" = {
      source = ../config/scripts/emoji-fuzzel;
      executable = true;
    };
    ".local/bin/zed".source = "${pkgs.zed-editor}/bin/zeditor";
    ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
  };

  home.activation = lib.optionalAttrs (!isServer) {
    installFuzzelConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -e "$HOME/.config/fuzzel" ]; then
        $DRY_RUN_CMD rm -rf "$HOME/.config/fuzzel"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/fuzzel"
      $DRY_RUN_CMD cp -r ${../config/fuzzel}/. "$HOME/.config/fuzzel/"
      $DRY_RUN_CMD chmod -R u+rwX "$HOME/.config/fuzzel"
    '';
  };

  programs.caelestia = lib.mkIf (!isServer) {
    enable = true;
    package = caelestiaShellPackage.override { withCli = true; };
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
    "keyd/app.conf".text = ''
      [com-mitchellh-ghostty]
      meta.c = C-S-c
      meta.v = C-S-v

      [*ghostty*]
      meta.c = C-S-c
      meta.v = C-S-v
    '';
    # Hide fcitx5 tray / layout indicator (classicui)
    "fcitx5/conf/classicui.conf".source = ../config/fcitx5/classicui.conf;
  };
}
