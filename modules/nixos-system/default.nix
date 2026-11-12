{
  delib,
  hostTraits,
  lib,
  pkgs,
  ...
}:
delib.module {
  name = "nixos.desktop";

  options =
    with delib;
    moduleOptions {
      enable = boolOption hostTraits.linuxDesktop;
      # Both backends resolve names through systemd-resolved.
      networkBackend = enumOption [ "iwd-networkd" "dhcpcd-resolved" ] "iwd-networkd";
    };

  nixos.ifEnabled =
    { cfg, myconfig, ... }:
    let
      usesIwdNetworkd = cfg.networkBackend == "iwd-networkd";
      hyprlandEnabled = myconfig.hyprland.enable;
      niriEnabled = myconfig.niri.enable;
    in
    {
      networking.useNetworkd = usesIwdNetworkd;
      networking.resolvconf.enable = lib.mkForce false;
      networking.wireless.iwd.enable = true;
      networking.wireless.iwd.settings = {
        General = {
          EnableNetworkConfiguration = usesIwdNetworkd;
        };
        Settings = {
          AutoConnect = true;
        };
      }
      // lib.optionalAttrs usesIwdNetworkd {
        Network = {
          # iwd defaults to systemd-resolved when it configures links itself.
          NameResolvingService = "systemd";
        };
      };
      services.resolved.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };

      hardware.bluetooth.enable = true;
      services.blueman.enable = true;

      services.upower.enable = true;
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

      programs.xwayland.enable = true;
      programs.nix-ld = {
        enable = true;
        # Allow third-party dynamically linked binaries, e.g. Zed external agents.
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
        configPackages = lib.mkIf niriEnabled [ pkgs.niri ];
        extraPortals =
          lib.optionals (!hyprlandEnabled) [ pkgs.xdg-desktop-portal-gtk ]
          ++ lib.optionals niriEnabled [ pkgs.xdg-desktop-portal-wlr ];
        config = {
          common.default =
            if hyprlandEnabled then
              [
                "hyprland"
                "gtk"
              ]
            else
              [ "gtk" ];
        }
        // lib.optionalAttrs niriEnabled {
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

      programs.niri.enable = niriEnabled;
      security.rtkit.enable = true;

      environment.systemPackages = with pkgs; [
        wget
        gcc
        iwd
        clang
        cl
        nodejs
      ];
    };
}
