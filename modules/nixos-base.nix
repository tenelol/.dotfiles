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
    nix.settings.ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

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
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
    };

    nixpkgs.config.allowUnfree = true;
    environment.variables.EDITOR = "nvim";
    environment.systemPackages = with pkgs; [
      bubblewrap
      git
      neovim
      nh
      tailscale
    ];
    programs.fish.enable = true;
    programs.fish.useBabelfish = true;
    security.sudo.extraConfig = ''Defaults env_keep += "EDITOR VISUAL"'';
    services.tailscale.enable = true;
    # Codex probes a conventional FHS path for bubblewrap on Linux.
    systemd.tmpfiles.rules = [
      "L+ /usr/bin/bwrap - - - - ${pkgs.bubblewrap}/bin/bwrap"
    ];

    system.stateVersion = "25.05";
  };
}
