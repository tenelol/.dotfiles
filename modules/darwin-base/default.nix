{
  delib,
  host,
  pkgs,
  profile,
  ...
}:
delib.module {
  name = "darwin.base";

  options = delib.singleEnableOption (builtins.match ".*-darwin" host.system != null);

  darwin.ifEnabled = {
    system.primaryUser = profile.username;
    system.stateVersion = 6;

    users.users.${profile.username} = {
      name = profile.username;
      home = "/Users/${profile.username}";
      shell = pkgs.fish;
    };

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    nix.gc = {
      automatic = true;
      interval = [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ];
      options = "--delete-older-than 7d";
    };

    nixpkgs.config.allowUnfree = true;

    environment.variables = {
      EDITOR = "nvim";
      LANG = "en_US.UTF-8";
      # Match NixOS: English messages with Japanese regional formats. macOS
      # libc has no LC_ADDRESS, LC_PAPER or the other glibc-only categories.
      LC_MONETARY = "ja_JP.UTF-8";
      LC_NUMERIC = "ja_JP.UTF-8";
      LC_TIME = "ja_JP.UTF-8";
    };
    environment.shells = [ pkgs.fish ];
    # Keep system packages minimal; user-facing CLI tooling lives in denix home modules.
    environment.systemPackages = with pkgs; [
      fish
      git
      neovim
      nh
    ];

    programs.fish.enable = true;

    security.pam.services.sudo_local.touchIdAuth = true;

    system.activationScripts.setFishLoginShell.text = ''
      grep -qx '/run/current-system/sw/bin/fish' /etc/shells || printf '\n/run/current-system/sw/bin/fish\n' >> /etc/shells
      dscl . -create /Users/${profile.username} UserShell /run/current-system/sw/bin/fish
    '';
  };
}
