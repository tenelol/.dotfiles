{ delib, host, pkgs, ... }:
delib.module {
  name = "nixos.host.nixos-server";

  options = delib.singleEnableOption (host.name == "nixos-server");

  nixos.ifEnabled = {
    networking.hostName = "nixos-server";
    networking.firewall.allowedTCPPorts = [ 80 8080 ];

    users.users.tener = {
      extraGroups = [ "video" "input" "seat" "audio" "network" "wheel" ];
      openssh.authorizedKeys.keyFiles = [ ../keys/tener.pub ];
    };

    services.getty.autologinUser = "tener";
    services.seatd.enable = true;

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

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        # TODO: Set to false after adding your public key to keys/tener.pub.
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

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };

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
        User = "tener";
        Group = "users";
      };
    };
  };
}
