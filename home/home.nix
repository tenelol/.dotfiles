{ host, pkgs, lib, inputs, config, ... }:
let
  isServer = host.isServer or false;
  isDesktop = (host.type or null) == "desktop";
  homeDir = config.home.homeDirectory;

  codexBarPackage = import ../packages/codexbar.nix {
    inherit pkgs lib;
  };
in
{
  home.username = "tener";
  home.homeDirectory = "/home/${config.home.username}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionPath = [
    "/run/wrappers/bin"
    "${homeDir}/.npm-global/bin"
    "${homeDir}/.local/bin"
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
      grim
      playerctl
      pulseaudio
      iw
      iproute2
      iputils
      ghostty
      libnotify
      slurp
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
      wl-clipboard
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
    ".local/bin/niri-screenshot" = {
      source = ../config/scripts/niri-screenshot;
      executable = true;
    };
    ".local/bin/zed".source = "${pkgs.zed-editor}/bin/zeditor";
    ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
  };

  xdg.configFile = lib.optionalAttrs (!isServer) ({
    "caelestia/shell.json".text = ''
      {
        "paths": {
          "wallpaperDir": "${config.xdg.configHome}/wallpapers",
          "sessionGif": "root:/assets/kurukuru.gif",
          "mediaGif": "root:/assets/bongocat.gif"
        }
      }
    '';
    "caelestia/cli.json".text = "{}";
    "wallpapers".source = ../img;
    "keyd/app.conf".text = ''
      [com-mitchellh-ghostty]
      meta.c = C-S-c
      meta.v = C-S-v

      [*ghostty*]
      meta.c = C-S-c
      meta.v = C-S-v
    '';
    "fcitx5/conf/classicui.conf".source = ../config/fcitx5/classicui.conf;
  } // lib.optionalAttrs isDesktop {
    "quickshell/caelestia".source = ../config/caelestia;
  });
}
