{
  host,
  pkgs,
  lib,
  config,
  inputs,
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
  ccpocketBridgePackage = import ../packages/ccpocket-bridge.nix {
    inherit pkgs lib;
  };
  moocsCollectPackage = import ../packages/moocs-collect.nix {
    inherit pkgs lib;
  };
  moocsCollectCliPackage = import ../packages/moocs-collect-cli.nix {
    inherit pkgs lib;
  };
  imoocsPackage = import ../packages/imoocs.nix {
    inherit pkgs lib;
    collectCli = moocsCollectCliPackage;
  };
  gijirokuPackage = import ../packages/gijiroku.nix {
    inherit pkgs lib;
    src = inputs.gijiroku;
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
    eza
    bat
    gomi
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
    imoocsPackage
    moocsCollectCliPackage
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
    gijirokuPackage
    moocsCollectPackage
    sqlitebrowser
    unicode-emoji
    obsidian
    vesktop
    zathura
  ];

  darwinCliPackages = with pkgs; [
    ccpocketBridgePackage
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
    "fcitx5/conf/classicui.conf".source = ../config/fcitx5/classicui.conf;
  };
}
