{
  delib,
  host,
  lib,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.desktop";

  options =
    with delib;
    moduleOptions {
      enable = boolOption (!host.isServer && builtins.match ".*-linux" host.system != null);
      networkBackend = strOption "iwd-networkd";
    };

  nixos.ifEnabled =
    { myconfig, ... }:
    let
      networkBackend = myconfig.nixos.desktop.networkBackend;
      usesIwdNetworkd = networkBackend == "iwd-networkd";
      usesDhcpcdResolved = networkBackend == "dhcpcd-resolved";
    in
    {
      assertions = [
        {
          assertion = builtins.elem networkBackend [
            "iwd-networkd"
            "dhcpcd-resolved"
          ];
          message = "myconfig.nixos.desktop.networkBackend must be one of iwd-networkd or dhcpcd-resolved.";
        }
      ];

      networking.networkmanager.enable = false;
      networking.useNetworkd = usesIwdNetworkd;
      networking.wireless.iwd.enable = true;
      networking.wireless.iwd.settings = {
        General = {
          EnableNetworkConfiguration = usesIwdNetworkd;
        };
        Settings = {
          AutoConnect = true;
        };
      };
      services.resolved.enable = usesDhcpcdResolved;

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
        GTK_IM_MODULE = "fcitx";
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
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
        ];
        config = {
          common.default = [ "gtk" ];
          niri = {
            default = lib.mkForce [
              "wlr"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Screencast" = [ "wlr" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          };
        };
      };

      programs.niri.enable = true;

      security.rtkit.enable = true;

      users.users.${profile.username} = {
        extraGroups = [ "keyd" ];
      };

      # Keep system packages focused on desktop integration and local tooling.
      environment.systemPackages = with pkgs; [
        wget
        gcc
        keyd
        iwd
        clang
        cl
        nodejs
      ];
    };
}
