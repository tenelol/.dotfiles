{
  delib,
  host,
  lib,
  pkgs,
  ...
}:
let
  mkConfig =
    myconfig:
    let
      networkBackend = myconfig.nixos.desktop.networkBackend;
      usesIwdNetworkd = networkBackend == "iwd-networkd";
      usesDhcpcdResolved = networkBackend == "dhcpcd-resolved";
      usesResolved = usesIwdNetworkd || usesDhcpcdResolved;
      hyprlandEnabled = myconfig.hyprland.enable or false;
      niriEnabled = myconfig.niri.enable or false;
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
      networking.resolvconf.enable = lib.mkForce (!usesResolved);
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
      services.resolved.enable = usesResolved;

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

      services.xserver.xkb = {
        layout = "us";
        variant = "";
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
in
delib.module {
  name = "nixos.desktop";

  options =
    with delib;
    moduleOptions {
      enable = boolOption (!host.isServer && builtins.match ".*-linux" host.system != null);
      networkBackend = strOption "iwd-networkd";
    };

  nixos.ifEnabled = { myconfig, ... }: mkConfig myconfig;
}
