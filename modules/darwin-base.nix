{
  delib,
  host,
  pkgs,
  ...
}:
delib.module {
  name = "darwin.base";

  options = delib.singleEnableOption (builtins.match ".*-darwin" host.system != null);

  darwin.ifEnabled = {
    system.primaryUser = "tener";
    system.stateVersion = 6;

    users.users.tener = {
      name = "tener";
      home = "/Users/tener";
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

    environment.variables.EDITOR = "nvim";
    environment.systemPackages = with pkgs; [
      bat
      cargo
      clang
      cmake
      coreutils
      eza
      fd
      findutils
      fish
      gawk
      git
      gnugrep
      gnumake
      gnused
      gnutar
      go
      jdk
      neovim
      nh
      nil
      nodejs
      nodePackages.prettier
      pkg-config
      pnpm
      prettierd
      python3
      ripgrep
      tre-command
      wget
      yazi
      zellij
      zig
    ];

    fonts.packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      jetbrains-mono
      fira-code
      hack-font
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.caskaydia-cove
      material-symbols
    ];

    programs.fish.enable = true;

    security.pam.services.sudo_local.touchIdAuth = true;

    system.defaults = {
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      dock = {
        autohide = true;
        mru-spaces = false;
        show-recents = false;
        showhidden = true;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };
}
