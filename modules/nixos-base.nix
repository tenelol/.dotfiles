{
  delib,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "nixos.base";

  nixos.always = {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
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
    networking.wireless.iwd.enable = true;
    networking.wireless.iwd.settings = {
      General = {
        EnableNetworkConfiguration = true;
      };
      Settings = {
        AutoConnect = true;
      };
    };

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

    users.users.${profile.username} = {
      isNormalUser = true;
      description = profile.username;
    };

    nixpkgs.config.allowUnfree = true;
    environment.variables.EDITOR = "nvim";
    environment.systemPackages = with pkgs; [
      bubblewrap
    ];
    security.sudo.extraConfig = ''Defaults env_keep += "EDITOR VISUAL"'';
    services.tailscale.enable = true;
    # Codex probes a conventional FHS path for bubblewrap on Linux.
    systemd.tmpfiles.rules = [
      "L+ /usr/bin/bwrap - - - - ${pkgs.bubblewrap}/bin/bwrap"
    ];

    system.stateVersion = "25.05";
  };
}
