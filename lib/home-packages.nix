{
  pkgs,
  lib,
  inputs,
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  system = pkgs.stdenv.hostPlatform.system;
  herdrPackage = inputs.herdr.packages.${system}.default;
  hermesAgentPackages = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};

  hermesAgentDesktopAppPackage = import ../packages/hermes-agent-desktop-app.nix {
    inherit pkgs lib;
    hermesDesktop = hermesAgentPackages.desktop;
  };
  codexBarPackage = import ../packages/codexbar.nix {
    inherit pkgs lib;
  };
  ccpocketBridgePackage = import ../packages/ccpocket-bridge.nix {
    inherit pkgs lib;
  };
  moocsCollectPackage = import ../packages/moocs-collect.nix {
    inherit pkgs lib;
  };
  imoocsPackage = import ../packages/imoocs.nix {
    inherit pkgs lib;
  };
  gijirokuPackage = import ../packages/gijiroku.nix {
    inherit pkgs lib;
    src = inputs.gijiroku;
  };
  iniadCommitPackage = import ../packages/iniad-commit.nix {
    inherit pkgs lib;
  };
  palmierProPackage = import ../packages/palmier-pro.nix {
    inherit pkgs lib;
  };

  commonPackages = with pkgs; [
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
    iniadCommitPackage
    nodejs
    python3
  ];

  linuxBasePackages = with pkgs; [
    parted
  ];

  nonServerPackages = with pkgs; [
    cargo
    herdrPackage
    imoocsPackage
    platformio
    pnpm
    supabase-cli
    zig
  ];

  linuxDesktopPackages = with pkgs; [
    adwaita-icon-theme
    codexBarPackage
    hermesAgentPackages.desktop
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

  darwinDesktopPackages = with pkgs; [
    hermesAgentDesktopAppPackage
    gijirokuPackage
    moocsCollectPackage
    palmierProPackage
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
  forHost =
    {
      isServer ? false,
    }:
    commonPackages
    ++ lib.optionals isLinux linuxBasePackages
    ++ lib.optionals (!isServer) nonServerPackages
    ++ lib.optionals (!isServer && isLinux) linuxDesktopPackages
    ++ lib.optionals (!isServer && isDarwin) (darwinCliPackages ++ darwinDesktopPackages)
    ++ lib.optionals (isServer && isLinux) linuxServerPackages;
}
