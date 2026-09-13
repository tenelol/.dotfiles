{
  delib,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  isServer = host.isServer or false;
  fullDesktop = host.fullDesktopFeatured;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  system = pkgs.stdenv.hostPlatform.system;
  herdrPackage = inputs.herdr.packages.${system}.default;
  ccpocketBridgePackage = import ../../packages/ccpocket-bridge.nix {
    inherit pkgs lib;
  };
  moocsCollectPackage = import ../../packages/moocs-collect.nix {
    inherit pkgs lib;
  };
  imoocsPackage = import ../../packages/imoocs.nix {
    inherit pkgs lib;
  };
  iniadCommitPackage = import ../../packages/iniad-commit.nix {
    inherit pkgs lib;
  };
  commonPackages = [
    iniadCommitPackage
  ];

  linuxCommonPackages = with pkgs; [
    awscli2
    cloudflared
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
    nodejs
    python3
  ];

  linuxBasePackages = with pkgs; [
    parted
  ];

  nonServerPackages = [
    herdrPackage
    imoocsPackage
  ];

  linuxNonServerPackages = with pkgs; [
    cargo
    platformio
    pnpm
    supabase-cli
    zig
  ];

  linuxDesktopPackages = with pkgs; [
    adwaita-icon-theme
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
    imv
    swaylock
    unicode-emoji
    wtype
    ydotool
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

  linuxFullDesktopPackages = with pkgs; [
    sqlitebrowser
    obsidian
    slack
    libreoffice-fresh
  ];

  darwinDesktopPackages = with pkgs; [
    moocsCollectPackage
  ];

  darwinCliPackages = with pkgs; [
    ccpocketBridgePackage
    nil
    nushell
  ];

  linuxServerPackages = with pkgs; [
    cmake
    gnumake
    pkg-config
  ];
in
delib.module {
  name = "home-packages";

  home.always.home.packages =
    lib.optionals (!isServer) commonPackages
    ++ lib.optionals (isLinux && !isServer) linuxCommonPackages
    ++ lib.optionals isLinux linuxBasePackages
    ++ lib.optionals (!isServer) nonServerPackages
    ++ lib.optionals (!isServer && isLinux) linuxNonServerPackages
    ++ lib.optionals (!isServer && isLinux) linuxDesktopPackages
    ++ lib.optionals (!isServer && isLinux && fullDesktop) linuxFullDesktopPackages
    ++ lib.optionals (!isServer && isDarwin) darwinCliPackages
    ++ lib.optionals (!isServer && isDarwin && fullDesktop) darwinDesktopPackages
    ++ lib.optionals (isServer && isLinux) linuxServerPackages;
}
