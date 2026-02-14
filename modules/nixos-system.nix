{ delib, host, lib, pkgs, ... }:
delib.module {
  name = "nixos.common";

  options = delib.singleEnableOption (
    host.name == "nixos" || host.name == "nvidia-desktop"
  );

  nixos.ifEnabled = {
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 5;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.networkmanager.enable = false;
    networking.useNetworkd = true;
    networking.wireless.iwd.enable = true;
    networking.wireless.iwd.settings = {
      General = {
        EnableNetworkConfiguration = true;
      };
      Settings = { AutoConnect = true; };
    };

    # Battery/UPower (for残量取得)
    services.upower.enable = true;

    services.tailscale.enable = true;

    time.timeZone = "Asia/Tokyo";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "ja_JP.UTF-8";
      LC_IDENTIFICATION = "ja_JP.UTF-8";
      LC_MEASUREMENT = "ja_JP.UTF-8";
      LC_MONETARY = "ja_JP.UTF-8";
      LC_NAME = "ja_JP.UTF-8";
      LC_NUMERIC = "ja_JP.UTF-8";
      LC_PAPER = "ja_JP.UTF-8";
      LC_TELEPHONE = "ja_JP.UTF-8";
      LC_TIME = "ja_JP.UTF-8";
    };

    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "layer(control)";
            # space = "overload(shift, space)"; # SandS disabled for games
          };
          meta = {
            c = "C-c";
            v = "C-v";
            x = "C-x";
            z = "C-z";
            a = "C-a";
            w = "A-f4";
          };
        };
      };
    };
    users.groups.keyd = { };
    systemd.services.keyd.serviceConfig = {
      Group = "keyd";
      # Keep keyd's socket readable by the keyd group for keyd-application-mapper.
      UMask = lib.mkForce "0007";
    };

    services.xserver.desktopManager.runXdgAutostartIfNone = true;

    environment.variables = {
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
    };

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        jetbrains-mono
        fira-code
        hack-font
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
      ];
    };

    services.xserver.xkb = { layout = "us"; variant = ""; };

    programs.hyprland.enable = true;
    programs.xwayland.enable = true;
    programs.nix-ld = {
      enable = true;
      # Allow third-party dynamically linked binaries (e.g. OpenCode) to run on NixOS.
      libraries = with pkgs; [ stdenv.cc.cc ];
    };
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
      config = {
        common.default = "wlr";
        hyprland.default = "hyprland";
        niri.default = lib.mkForce "wlr";
      };
    };

    programs.niri.enable = true;

    security.rtkit.enable = true;

    programs.fish.enable = true;
    programs.fish.useBabelfish = true;

    users.users.tener = {
      isNormalUser = true;
      description = "tener";
      extraGroups = [ "wheel" "network" "keyd" ];
      packages = with pkgs; [ ];
      shell = pkgs.fish;
    };

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      vim
      wget
      git
      keyd
      iwd
      adwaita-icon-theme
      gcc
      cl
      zig
      clang
      neovim
      nodejs
      nodePackages.npm
      go
      cargo
      python3
      tailscale
      pnpm
      xwayland-satellite
      nh
    ];

    environment.variables.EDITOR = "nvim";
    security.sudo.extraConfig = ''Defaults env_keep += "EDITOR VISUAL"'';

    system.stateVersion = "25.05";
  };
}
