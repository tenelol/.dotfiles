{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.host.nixos-server";

  options = delib.singleEnableOption (host.name == "nixos-server");

  nixos.ifEnabled = {
    networking.hostName = "nixos-server";

    users.users.${profile.username} = {
      extraGroups = [
        "video"
        "input"
        "seat"
        "audio"
        "wheel"
      ];
      openssh.authorizedKeys.keyFiles = [ profile.sshPublicKey ];
    };

    services.seatd.enable = true;

    # Keep host packages to server operations; user tooling comes from Home Manager.
    environment.systemPackages = with pkgs; [
      gcc
      iwd
      clang
      neovim
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

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
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
  };
}
