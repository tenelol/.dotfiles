{ delib, host, pkgs, ... }:
delib.module {
  name = "nixos.host.nixos-server";

  options = delib.singleEnableOption (host.name == "nixos-server");

  nixos.ifEnabled = {
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 5;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "nixos-server";
    networking.networkmanager.enable = false;
    networking.wireless.iwd.enable = true;
    networking.wireless.iwd.settings = {
      General = { EnableNetworkConfiguration = true; };
      Settings = { AutoConnect = true; };
    };
    networking.firewall.allowedTCPPorts = [ 80 8080 ];

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

    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.tener = {
      isNormalUser = true;
      description = "tener";
      extraGroups = [ "video" "input" "seat" "audio" "network" "wheel" ];
      packages = with pkgs; [ ];
    };

    environment.variables = {
      EDITOR = "nvim";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
    };

    services.getty.autologinUser = "tener";
    services.seatd.enable = true;

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      neovim
      wget
      git
      gcc
      gnumake
      pkg-config
      cmake
      ripgrep
      nodejs
      python3
      iwd
      go
      cloudflared
      gh
      tailscale
      nh
    ];

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-skk
        qt6Packages.fcitx5-configtool
      ];
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

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    security.sudo.extraConfig = ''Defaults env_keep += "EDITOR VISUAL"'';

    services.nginx = {
      enable = true;
      virtualHosts."local-portfolio" = {
        listen = [
          { addr = "0.0.0.0"; port = 80; }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
        };
      };
    };

    services.cloudflared = {
      enable = true;
      tunnels."mywebfw" = {
        credentialsFile = "/var/lib/cloudflared/mywebfw.json";
        ingress = {
          "tenelol.dev" = "http://localhost:8080";
        };
        default = "http_status:404";
      };
    };

    services.tailscale.enable = true;

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
      };
    };

    services.logind.settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };

    systemd.sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
      AllowHybridSleep=no
      AllowSuspendThenHibernate=no
    '';

    system.stateVersion = "25.05";

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        vulkan-loader
        vulkan-tools
        libva
      ];
    };

    systemd.services.portfolio = {
      description = "Portfolio Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "/home/tener/projects/portfolio/result/bin/server";
        Restart = "always";
        WorkingDirectory = "/home/tener/projects/portfolio";
      };
    };
  };
}
