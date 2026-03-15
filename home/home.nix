{
  host,
  pkgs,
  lib,
  config,
  profile,
  ...
}:
let
  isServer = host.isServer or false;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = config.home.homeDirectory;

  codexBarPackage = import ../packages/codexbar.nix {
    inherit pkgs lib;
  };

  commonPackages = with pkgs; [
    gh
    zellij
    eza
    bat
    tre-command
    ripgrep
    jdk
    prettierd
    nodePackages.prettier
  ];

  linuxBasePackages = with pkgs; [
    parted
  ];

  linuxDesktopPackages = with pkgs; [
    codexBarPackage
    acpi
    alsa-utils
    brightnessctl
    cliphist
    grim
    playerctl
    pulseaudio
    iw
    iproute2
    iputils
    libnotify
    slurp
    swww
    wofi
    fuzzel
    floorp-bin
    google-chrome
    sqlitebrowser
    imv
    swaylock
    unicode-emoji
    wtype
    ydotool
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

  darwinDesktopPackages = with pkgs; [
    floorp-bin
    google-chrome
    sqlitebrowser
    unicode-emoji
    obsidian
    vesktop
    slack
    vscode
    zed-editor
    zathura
  ];
in
{
  home.username = lib.mkDefault profile.username;
  home.homeDirectory = lib.mkDefault (
    if isDarwin then "/Users/${config.home.username}" else "/home/${config.home.username}"
  );
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionPath = [
    "${homeDir}/.npm-global/bin"
    "${homeDir}/.local/bin"
  ]
  ++ lib.optionals isLinux [
    "/run/wrappers/bin"
  ]
  ++ lib.optionals isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
  ];

  home.sessionVariables = {
    JAVA_HOME = pkgs.jdk.home;
  };

  home.packages =
    commonPackages
    ++ lib.optionals isLinux linuxBasePackages
    ++ lib.optionals (!isServer && isLinux) linuxDesktopPackages
    ++ lib.optionals (!isServer && isDarwin) darwinDesktopPackages;

  home.file =
    lib.optionalAttrs (!isServer && isLinux) {
      ".local/bin/emoji-fuzzel" = {
        source = ../config/scripts/emoji-fuzzel;
        executable = true;
      };
      ".local/bin/niri-screenshot" = {
        source = ../config/scripts/niri-screenshot;
        executable = true;
      };
    }
    // lib.optionalAttrs (!isServer) {
      ".local/bin/zed".source = "${pkgs.zed-editor}/bin/zeditor";
    }
    // lib.optionalAttrs (!isServer) {
      ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
    };

  xdg.configFile =
    lib.optionalAttrs (!isServer) {
      "wallpapers".source = ../img;
    }
    // lib.optionalAttrs (!isServer && isLinux) {
      "keyd/app.conf".text = ''
        [com-mitchellh-ghostty]
        meta.c = C-S-c
        meta.v = C-S-v

        [*ghostty*]
        meta.c = C-S-c
        meta.v = C-S-v
      '';
      "fcitx5/conf/classicui.conf".source = ../config/fcitx5/classicui.conf;
    };
}
