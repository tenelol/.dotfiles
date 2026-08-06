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
  hermesPython = pkgs.python312.override {
    packageOverrides = _final: previous: {
      # Torch is only used by ctranslate2's package tests, not at runtime.
      ctranslate2 = previous.ctranslate2.overridePythonAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    };
  };
  hermesCallPackage = lib.callPackageWith (pkgs // { python312 = hermesPython; });
  hermesAgentPackage = hermesAgentPackages.default.override { callPackage = hermesCallPackage; };
  hermesDesktopPackage = pkgs.callPackage "${inputs.hermes-agent}/nix/desktop.nix" {
    pkgs = pkgs // {
      # Electron's v41.9.1 headers were republished after Hermes pinned them.
      fetchurl =
        args: pkgs.fetchurl (args // { sha256 = "sha256-zOl8rx6woWh7aeRUOlkTMviKc/EAQQX6nr/MxAx1ZPI="; });
    };
    hermesNpmLib = hermesAgentPackage.hermesNpmLib;
    hermesAgent = hermesAgentPackage;
  };

  hermesAgentDesktopAppPackage = import ../packages/hermes-agent-desktop-app.nix {
    inherit pkgs lib;
    hermesDesktop = hermesDesktopPackage;
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
  iniadCommitPackage = import ../packages/iniad-commit.nix {
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
    hermesDesktopPackage
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
    google-chrome
    sqlitebrowser
    obsidian
    vesktop
    slack
    libreoffice-fresh
  ];

  darwinDesktopPackages = with pkgs; [
    hermesAgentDesktopAppPackage
    moocsCollectPackage
  ];

  darwinCliPackages = with pkgs; [
    ccpocketBridgePackage
    nil
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
      fullDesktop ? false,
    }:
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
