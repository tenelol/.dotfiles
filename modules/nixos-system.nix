{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.common";

  options = delib.singleEnableOption (host.name == "nixos" || host.name == "nvidia-desktop");

  nixos.ifEnabled = {
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;

    nix.settings.ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    networking.useNetworkd = true;

    # バッテリー残量取得
    services.upower.enable = true;

    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "layer(control)";
            # space = "overload(shift, space)"; # SandS disabled for games
          };
          # Use Super as the "Command" key for app shortcuts.
          meta = {
            a = "C-a";
            c = "C-c";
            f = "C-f";
            r = "C-r";
            s = "C-s";
            t = "C-t";
            v = "C-v";
            w = "C-w";
            x = "C-x";
            y = "C-y";
            z = "C-z";
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

    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    programs.xwayland.enable = true;
    programs.nix-ld = {
      enable = true;
      # Allow third-party dynamically linked binaries (e.g. Zed external agents) to run on NixOS.
      libraries = with pkgs; [
        stdenv.cc.cc
        libcap
        xz
        openssl
        zlib
      ];
    };
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      configPackages = [ pkgs.niri ];
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [ "gtk" ];
        niri = {
          default = [ "gnome" "gtk" ];
          "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        };
      };
    };

    programs.niri.enable = true;

    security.rtkit.enable = true;

    programs.fish.enable = true;
    programs.fish.useBabelfish = true;

    users.users.${profile.username} = {
      extraGroups = [
        "wheel"
        "keyd"
      ];
      shell = pkgs.fish;
    };

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
  };
}
