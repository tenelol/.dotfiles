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
  mygdrivePackage = import ../packages/mygdrive.nix {
    inherit pkgs lib;
  };
  moocsCollectPackage = import ../packages/moocs-collect.nix {
    inherit pkgs lib;
  };
  notchMusicPackage = import ../packages/notchmusic.nix {
    inherit pkgs lib;
  };
  iniadCommitPackage = import ../packages/iniad-commit.nix {
    inherit pkgs lib;
  };

  # User-facing CLI and dev tools live in Home Manager so they stay aligned
  # across Linux and Darwin without bloating system-level package sets.
  commonPackages = with pkgs; [
    gh
    gdrive
    cowsay
    lolcat
    zellij
    eza
    bat
    gomi
    mygdrivePackage
    tre-command
    ripgrep
    prettierd
    prettier
    go
    iniadCommitPackage
    nodejs
    python3
  ];

  linuxBasePackages = with pkgs; [
    parted
  ];

  nonServerPackages = with pkgs; [
    cargo
    platformio
    pnpm
    zig
  ];

  linuxDesktopPackages = with pkgs; [
    adwaita-icon-theme
    codexBarPackage
    acpi
    alsa-utils
    brightnessctl
    cliphist
    ghostty
    grim
    playerctl
    pulseaudio
    iw
    iproute2
    iputils
    libnotify
    slurp
    awww
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
    waybar
    wl-clipboard
    xwayland-satellite
    zathura
    antigravity-fhs
    noto-fonts
    noto-fonts-color-emoji
    pkgs.nerd-fonts.caskaydia-cove
    pkgs.material-symbols
  ];

  # Prefer Nix here when the package is cross-platform or when keeping the
  # same binary/toolchain as Linux is useful.
  darwinDesktopPackages = with pkgs; [
    google-chrome
    moocsCollectPackage
    notchMusicPackage
    sqlitebrowser
    unicode-emoji
    obsidian
    vesktop
    zathura
  ];

  darwinCliPackages = with pkgs; [
    clang
    cmake
    coreutils
    fd
    findutils
    gawk
    gnugrep
    gnumake
    gnused
    gnutar
    nil
    pkg-config
    wget
    yazi
  ];

  linuxServerPackages = with pkgs; [
    cmake
    gnumake
    pkg-config
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
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages =
    commonPackages
    ++ lib.optionals isLinux linuxBasePackages
    ++ lib.optionals (!isServer) nonServerPackages
    ++ lib.optionals (!isServer && isLinux) linuxDesktopPackages
    ++ lib.optionals (!isServer && isDarwin) (darwinCliPackages ++ darwinDesktopPackages)
    ++ lib.optionals (isServer && isLinux) linuxServerPackages;

  home.file =
    lib.optionalAttrs (!isServer) {
      ".local/bin/ushi" = {
        source = ../config/scripts/ushi;
        executable = true;
      };
    }
    // lib.optionalAttrs (!isServer && isLinux) {
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
      ".config/fontconfig/fonts.conf".source = ../config/fontconfig/fonts.conf;
    };

  xdg.configFile = lib.optionalAttrs (!isServer && isLinux) {
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
