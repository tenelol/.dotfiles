{
  delib,
  host,
  hostTraits,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  herdrPackage =
    let
      binary = inputs.herdr-bin.packages.${system}.default;
    in
    assert binary.version == (lib.importTOML "${inputs.herdr}/Cargo.toml").package.version;
    binary;
  ccpocketBridgePackage = import ../../packages/ccpocket-bridge.nix {
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
    imoocsPackage
  ];

  linuxNonServerPackages = with pkgs; [
    herdrPackage
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
    antigravity-ide-fhs
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.caskaydia-cove
    material-symbols
  ];

  linuxFullDesktopPackages = with pkgs; [
    sqlitebrowser
    obsidian
    slack
    libreoffice-stable
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
    # The list order is part of the profile derivation; keep it when regrouping.
    lib.optionals hostTraits.desktop commonPackages
    ++ lib.optionals hostTraits.linuxDesktop linuxCommonPackages
    ++ lib.optionals hostTraits.linux linuxBasePackages
    ++ lib.optionals hostTraits.desktop nonServerPackages
    ++ lib.optionals hostTraits.linuxDesktop (linuxNonServerPackages ++ linuxDesktopPackages)
    ++ lib.optionals (hostTraits.linuxDesktop && host.fullDesktopFeatured) linuxFullDesktopPackages
    ++ lib.optionals hostTraits.darwinDesktop darwinCliPackages
    ++ lib.optionals (hostTraits.linux && host.isServer) linuxServerPackages;
}
